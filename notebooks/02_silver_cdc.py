# Databricks notebook source
# Silver: applies CDC from bronze to current-state tables, one per capture instance.
# synthea.bronze.<instance> (append only) -> synthea.silver.<instance> via Delta MERGE on ID.
# Per micro-batch: keep the latest change per ID (_lsn), then insert / update / delete.
# Guard: a change only applies if its _lsn >= the row's _lsn, so replays and re-extracts are safe.
# Cleanup: city names title case (organizations send UPPERCASE), Zip 00000 -> NULL.
from typing import Callable, Dict, List

from delta.tables import DeltaTable
from pyspark.sql import DataFrame, Window
from pyspark.sql import functions as F

checkpoint_root: str = "/Volumes/synthea/landing/cdc/_checkpoints"
instances: List[str] = [
    "ref_Location", "ref_Code", "ref_Payer", "ref_Organization", "ref_Provider",
    "clinical_Patient", "clinical_Encounter", "clinical_Condition", "clinical_Medication", "clinical_Procedure",
]
metadata_columns: List[str] = ["_op", "_lsn", "_extracted_at", "_source_file", "_ingested_at", "_rescued_data"]


def latest_per_id(df: DataFrame) -> DataFrame:
    window = Window.partitionBy("ID").orderBy(F.col("_lsn").desc(), F.col("_ingested_at").desc())
    return df.withColumn("_rn", F.row_number().over(window)).filter(F.col("_rn") == 1).drop("_rn")


def clean(instance: str, df: DataFrame) -> DataFrame:
    if instance == "ref_Location":
        return df.withColumn("Name", F.when(F.col("LocationType") == "City", F.initcap("Name")).otherwise(F.col("Name")))
    if instance == "clinical_Patient":
        return df.withColumn("Zip", F.when(F.col("Zip") == "00000", F.lit(None)).otherwise(F.col("Zip")))
    return df


def make_upsert(instance: str, target: str) -> Callable[[DataFrame, int], None]:
    def upsert(batch_df: DataFrame, batch_id: int) -> None:
        latest: DataFrame = clean(instance, latest_per_id(batch_df))
        data_columns: List[str] = [c for c in latest.columns if c not in metadata_columns]
        source: DataFrame = latest.select(*data_columns, "_op", "_lsn").withColumn("_silver_updated_at", F.current_timestamp())
        keep_columns: List[str] = data_columns + ["_lsn", "_silver_updated_at"]

        if spark.catalog.tableExists(target) == False:
            source.filter(F.col("_op") != "D").select(*keep_columns).write.saveAsTable(target)
            return

        assignments: Dict[str, str] = {}
        for column in keep_columns:
            assignments[column] = "s." + column

        (
            DeltaTable.forName(spark, target).alias("t")
                .merge(source.alias("s"), "t.ID = s.ID")
                .whenMatchedDelete(condition="s._op = 'D' AND s._lsn >= t._lsn")
                .whenMatchedUpdate(condition="s._op <> 'D' AND s._lsn >= t._lsn", set=assignments)
                .whenNotMatchedInsert(condition="s._op <> 'D'", values=assignments)
                .execute()
        )
    return upsert


for instance in instances:
    source_table: str = "synthea.bronze." + instance.lower()
    target_table: str = "synthea.silver." + instance.lower()
    stream = (
        spark.readStream
            .table(source_table)
        .writeStream
            .foreachBatch(make_upsert(instance, target_table))
            .option("checkpointLocation", checkpoint_root + "/silver_" + instance)
            .trigger(availableNow=True)
            .start()
    )
    stream.awaitTermination()
    print(instance + " done")
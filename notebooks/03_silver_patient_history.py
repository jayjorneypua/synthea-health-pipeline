# Databricks notebook source
# Silver: patient history (SCD2), rebuilt from bronze each run (bronze holds every version).
# A new version starts only when a tracked column changes. ValidFrom = source UpdatedDate (or
# CreatedDate), ValidTo = next version's ValidFrom (exclusive), IsCurrent = no later version.
# A delete (_op = D) closes the last version and leaves no current row.
from typing import List

from pyspark.sql import DataFrame, Window
from pyspark.sql import functions as F

tracked_columns: List[str] = ["ID_Location", "Address", "Zip", "MaritalStatus", "Income", "DeathDate", "Deleted"]
metadata_columns: List[str] = ["_op", "_lsn", "_extracted_at", "_source_file", "_ingested_at", "_rescued_data"]

bronze: DataFrame = (
    spark.table("synthea.bronze.clinical_patient")
        .withColumn("Zip", F.when(F.col("Zip") == "00000", F.lit(None)).otherwise(F.col("Zip")))
)

by_lsn: Window = Window.partitionBy("ID").orderBy("_lsn", "_ingested_at")

hashed: DataFrame = (
    bronze
        .withColumn("_hash", F.sha2(F.concat_ws("||", *[F.coalesce(F.col(c).cast("string"), F.lit("~")) for c in tracked_columns]), 256))
        .withColumn("_prev_hash", F.lag("_hash").over(by_lsn))
        .withColumn("_prev_op", F.lag("_op").over(by_lsn))
)

# keep: deletes, the first row, rows whose tracked values changed, and the first row after a delete
changes: DataFrame = hashed.filter(
    (F.col("_op") == "D")
    | F.col("_prev_hash").isNull()
    | (F.col("_hash") != F.col("_prev_hash"))
    | (F.col("_prev_op") == "D")
)

with_from: DataFrame = changes.withColumn(
    "ValidFrom",
    F.when(F.col("_op") == "D", F.col("_extracted_at").cast("timestamp")).otherwise(F.coalesce(F.col("UpdatedDate"), F.col("CreatedDate"))),
)

history: DataFrame = (
    with_from
        .withColumn("ValidTo", F.lead("ValidFrom").over(by_lsn))
        .filter(F.col("_op") != "D")
        .withColumn("IsCurrent", F.col("ValidTo").isNull())
        .withColumn("PatientVersionKey", F.sha2(F.concat_ws("|", F.col("ID").cast("string"), F.col("_lsn")), 256))
)

data_columns: List[str] = [c for c in bronze.columns if c not in metadata_columns]
result: DataFrame = history.select("PatientVersionKey", *data_columns, "ValidFrom", "ValidTo", "IsCurrent")

(
    result.write
        .mode("overwrite")
        .option("overwriteSchema", "true")
        .saveAsTable("synthea.silver.clinical_patient_history")
)
print("clinical_patient_history: " + str(result.count()) + " rows")
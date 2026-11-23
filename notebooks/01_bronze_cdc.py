# Databricks notebook source
# Bronze: Auto Loader per capture instance.
# /Volumes/synthea/landing/cdc/<instance>/*.parquet -> synthea.bronze.<instance>
# Append only, rows exactly as extracted (_op, _lsn, _extracted_at) plus _source_file and _ingested_at.
# Silver applies the changes.
from typing import List

from pyspark.sql import functions as F

landing_root: str = "/Volumes/synthea/landing/cdc"
checkpoint_root: str = landing_root + "/_checkpoints"
instances: List[str] = [
    "ref_Location", "ref_Code", "ref_Payer", "ref_Organization", "ref_Provider",
    "clinical_Patient", "clinical_Encounter", "clinical_Condition", "clinical_Medication", "clinical_Procedure",
    "clinical_Claim", "clinical_ClaimLine",
]

for instance in instances:
    checkpoint_path: str = checkpoint_root + "/bronze_" + instance
    stream = (
        spark.readStream
            .format("cloudFiles")
            .option("cloudFiles.format", "parquet")
            .option("cloudFiles.schemaLocation", checkpoint_path)
            .option("cloudFiles.useIncrementalListing", "false")
            .option("pathGlobFilter", "*.parquet")
            .load(landing_root + "/" + instance + "/")
            .withColumn("_source_file", F.col("_metadata.file_path"))
            .withColumn("_ingested_at", F.current_timestamp())
        .writeStream
            .option("checkpointLocation", checkpoint_path)
            .trigger(availableNow=True)
            .toTable("synthea.bronze." + instance.lower())
    )
    stream.awaitTermination()
    print(instance + " done")
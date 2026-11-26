# Databricks notebook source
# Bronze: raw FHIR bundles, one row per JSON file (one patient per file).
# /Volumes/synthea/landing/fhir/bundles/*.json.gz -> synthea.bronze.fhir_bundle
# Kept as raw text. Silver does the flattening.
from pyspark.sql import functions as F

landing_path: str = "/Volumes/synthea/landing/fhir/bundles"
checkpoint_path: str = "/Volumes/synthea/landing/fhir/_checkpoints/bronze_fhir_bundle"

stream = (
    spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "text")
        .option("wholetext", "true")
        .option("pathGlobFilter", "*.json.gz")
        .load(landing_path)
        .withColumnRenamed("value", "bundle_json")
        .withColumn("_source_file", F.col("_metadata.file_path"))
        .withColumn("_ingested_at", F.current_timestamp())
    .writeStream
        .option("checkpointLocation", checkpoint_path)
        .trigger(availableNow=True)
        .toTable("synthea.bronze.fhir_bundle")
)
stream.awaitTermination()
print("fhir bundles done")
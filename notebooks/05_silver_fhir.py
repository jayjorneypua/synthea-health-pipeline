# Databricks notebook source
# Silver: flatten FHIR bundles into patient, encounter, condition and observation tables.
# De-identified in the same step:
#   patient ID becomes a salted SHA-256 hash, names, phone and street address are dropped,
#   zip is cut to 3 digits, and every date moves back a fixed 1 to 365 days per patient,
#   so gaps between dates (length of stay, days to readmission) stay correct.
# synthea.bronze.fhir_bundle -> synthea.silver.fhir_patient, fhir_encounter, fhir_condition, fhir_observation
import json
from typing import Dict

from pyspark.sql import Column, DataFrame
from pyspark.sql import functions as F

hash_salt: str = "synthea-fhir-deid"  # in real work this would come from a secret scope

coding_type: str = "ARRAY<STRUCT<system: STRING, code: STRING, display: STRING>>"
reference_type: str = "STRUCT<reference: STRING>"

# one row per FHIR resource, kept as raw JSON text until parsed by type
resources: DataFrame = (
    spark.table("synthea.bronze.fhir_bundle")
        .select(F.from_json("bundle_json", "entry ARRAY<STRUCT<resource: STRING>>").alias("bundle"))
        .select(F.explode("bundle.entry.resource").alias("resource_json"))
        .withColumn("resource_type", F.get_json_object("resource_json", "$.resourceType"))
)


def parse(resource_type: str, schema: str) -> DataFrame:
    return (
        resources
            .filter(F.col("resource_type") == resource_type)
            .select(F.from_json("resource_json", schema).alias("resource"))
            .select("resource.*")
            .dropDuplicates(["id"])
    )


def reference_id(column_name: str) -> Column:
    # "urn:uuid:abc" -> "abc"
    return F.regexp_replace(F.col(column_name), "^urn:uuid:", "")


def shift(column_name: str) -> Column:
    return F.expr("CAST(" + column_name + " AS TIMESTAMP) - make_dt_interval(shift_days)")


patient_raw: DataFrame = parse(
    "Patient",
    "id STRING, gender STRING, birthDate STRING, deceasedDateTime STRING, "
    "address ARRAY<STRUCT<state: STRING, postalCode: STRING>>",
)

# source ID -> hashed key and date shift, used by every table
patient_map: DataFrame = patient_raw.select(
    F.col("id").alias("source_patient_id"),
    F.sha2(F.concat(F.lit(hash_salt), F.col("id")), 256).alias("patient_key"),
    (F.pmod(F.xxhash64("id"), F.lit(365)) + 1).cast("int").alias("shift_days"),
)


def add_patient_key(source: DataFrame) -> DataFrame:
    # left join so rows pointing at a missing patient keep a NULL patient_key for the quality checks
    return source.join(patient_map, "source_patient_id", "left").drop("source_patient_id")


fhir_patient: DataFrame = (
    add_patient_key(
        patient_raw.select(
            F.col("id").alias("source_patient_id"),
            "gender",
            F.col("birthDate").alias("birth_raw"),
            F.col("deceasedDateTime").alias("death_raw"),
            F.col("address")[0]["state"].alias("state"),
            F.substring(F.col("address")[0]["postalCode"], 1, 3).alias("zip3"),
        )
    )
    .select(
        "patient_key",
        "gender",
        F.expr("date_sub(CAST(birth_raw AS DATE), shift_days)").alias("birth_date"),
        shift("death_raw").alias("death_at"),
        "state",
        "zip3",
    )
)

fhir_encounter: DataFrame = (
    add_patient_key(
        parse(
            "Encounter",
            "id STRING, status STRING, `class` STRUCT<code: STRING>, "
            "`type` ARRAY<STRUCT<coding: " + coding_type + ">>, "
            "subject " + reference_type + ", period STRUCT<start: STRING, `end`: STRING>",
        ).select(
            F.col("id").alias("encounter_id"),
            reference_id("subject.reference").alias("source_patient_id"),
            "status",
            F.col("class.code").alias("encounter_class"),
            F.col("type")[0]["coding"][0]["code"].alias("encounter_code"),
            F.col("type")[0]["coding"][0]["display"].alias("encounter_display"),
            F.col("period.start").alias("start_raw"),
            F.col("period.end").alias("end_raw"),
        )
    )
    .select(
        "encounter_id",
        "patient_key",
        "status",
        "encounter_class",
        "encounter_code",
        "encounter_display",
        shift("start_raw").alias("start_at"),
        shift("end_raw").alias("end_at"),
    )
)

fhir_condition: DataFrame = (
    add_patient_key(
        parse(
            "Condition",
            "id STRING, clinicalStatus STRUCT<coding: " + coding_type + ">, "
            "code STRUCT<coding: " + coding_type + ">, "
            "subject " + reference_type + ", encounter " + reference_type + ", "
            "onsetDateTime STRING, abatementDateTime STRING",
        ).select(
            F.col("id").alias("condition_id"),
            reference_id("subject.reference").alias("source_patient_id"),
            reference_id("encounter.reference").alias("encounter_id"),
            F.col("clinicalStatus.coding")[0]["code"].alias("clinical_status"),
            F.col("code.coding")[0]["system"].alias("code_system"),
            F.col("code.coding")[0]["code"].alias("condition_code"),
            F.col("code.coding")[0]["display"].alias("condition_display"),
            F.col("onsetDateTime").alias("onset_raw"),
            F.col("abatementDateTime").alias("abatement_raw"),
        )
    )
    .select(
        "condition_id",
        "patient_key",
        "encounter_id",
        "clinical_status",
        "code_system",
        "condition_code",
        "condition_display",
        shift("onset_raw").alias("onset_at"),
        shift("abatement_raw").alias("abatement_at"),
    )
)

fhir_observation: DataFrame = (
    add_patient_key(
        parse(
            "Observation",
            "id STRING, status STRING, category ARRAY<STRUCT<coding: " + coding_type + ">>, "
            "code STRUCT<coding: " + coding_type + ">, "
            "subject " + reference_type + ", encounter " + reference_type + ", "
            "effectiveDateTime STRING, valueQuantity STRUCT<value: DOUBLE, unit: STRING>, "
            "valueCodeableConcept STRUCT<coding: " + coding_type + ">",
        ).select(
            F.col("id").alias("observation_id"),
            reference_id("subject.reference").alias("source_patient_id"),
            reference_id("encounter.reference").alias("encounter_id"),
            "status",
            F.col("category")[0]["coding"][0]["code"].alias("category"),
            F.col("code.coding")[0]["system"].alias("code_system"),
            F.col("code.coding")[0]["code"].alias("observation_code"),
            F.col("code.coding")[0]["display"].alias("observation_display"),
            F.col("valueQuantity.value").alias("value_number"),
            F.col("valueQuantity.unit").alias("value_unit"),
            F.col("valueCodeableConcept.coding")[0]["display"].alias("value_text"),
            F.col("effectiveDateTime").alias("effective_raw"),
        )
    )
    .select(
        "observation_id",
        "patient_key",
        "encounter_id",
        "status",
        "category",
        "code_system",
        "observation_code",
        "observation_display",
        "value_number",
        "value_unit",
        "value_text",
        shift("effective_raw").alias("effective_at"),
    )
)

silver_tables: Dict[str, DataFrame] = {
    "fhir_patient": fhir_patient,
    "fhir_encounter": fhir_encounter,
    "fhir_condition": fhir_condition,
    "fhir_observation": fhir_observation,
}

row_counts: Dict[str, int] = {}
for table_name, table_data in silver_tables.items():
    full_name: str = "synthea.silver." + table_name
    table_data.write.mode("overwrite").option("overwriteSchema", "true").saveAsTable(full_name)
    row_counts[table_name] = spark.table(full_name).count()
    print(table_name + ": " + str(row_counts[table_name]))

dbutils.notebook.exit(json.dumps(row_counts))
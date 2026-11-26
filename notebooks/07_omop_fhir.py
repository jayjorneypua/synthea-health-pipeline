# Databricks notebook source
# OMOP CDM v5.4: person, visit_occurrence, condition_occurrence, measurement,
# built from the de-identified FHIR silver tables. Rows with a DQ error are left out.
# Gender, visit and type concept IDs are standard OMOP IDs. Condition and measurement
# concept IDs are 0 (unmapped) until the OMOP vocabulary is loaded; the original
# SNOMED and LOINC codes are kept in the *_source_value columns.
import json
from typing import Dict

from pyspark.sql import Column, DataFrame
from pyspark.sql import functions as F

ehr_type_concept_id: int = 32817  # record came from an EHR

spark.sql("CREATE SCHEMA IF NOT EXISTS synthea.omop")

error_rows: DataFrame = spark.table("synthea.silver.fhir_dq_failure").filter(F.col("severity") == "error")


def without_errors(source: DataFrame, id_column: str) -> DataFrame:
    return source.join(error_rows.select(F.col("record_id").alias(id_column)), id_column, "left_anti")


def omop_id(column_name: str) -> Column:
    # OMOP IDs are integers, so hash the text ID into a positive BIGINT
    return F.when(
        F.col(column_name).isNotNull(),
        F.xxhash64(column_name).bitwiseAND(F.lit(9223372036854775807)),
    )


patient: DataFrame = spark.table("synthea.silver.fhir_patient")
encounter: DataFrame = without_errors(spark.table("synthea.silver.fhir_encounter"), "encounter_id")
condition: DataFrame = without_errors(spark.table("synthea.silver.fhir_condition"), "condition_id")
observation: DataFrame = without_errors(spark.table("synthea.silver.fhir_observation"), "observation_id")

person: DataFrame = patient.select(
    omop_id("patient_key").alias("person_id"),
    F.when(F.col("gender") == "male", 8507)
        .when(F.col("gender") == "female", 8532)
        .otherwise(0).alias("gender_concept_id"),
    F.year("birth_date").alias("year_of_birth"),
    F.month("birth_date").alias("month_of_birth"),
    F.dayofmonth("birth_date").alias("day_of_birth"),
    F.col("birth_date").cast("timestamp").alias("birth_datetime"),
    F.lit(0).alias("race_concept_id"),
    F.lit(0).alias("ethnicity_concept_id"),
    F.col("patient_key").alias("person_source_value"),
    F.col("gender").alias("gender_source_value"),
)

visit_occurrence: DataFrame = encounter.select(
    omop_id("encounter_id").alias("visit_occurrence_id"),
    omop_id("patient_key").alias("person_id"),
    F.when(F.col("encounter_class") == "IMP", 9201)
        .when(F.col("encounter_class").isin("EMER", "URGENTCARE"), 9203)
        .when(F.col("encounter_class").isin("AMB", "WELLNESS", "OUTPATIENT"), 9202)
        .otherwise(0).alias("visit_concept_id"),
    F.to_date("start_at").alias("visit_start_date"),
    F.col("start_at").alias("visit_start_datetime"),
    F.to_date("end_at").alias("visit_end_date"),
    F.col("end_at").alias("visit_end_datetime"),
    F.lit(ehr_type_concept_id).alias("visit_type_concept_id"),
    F.col("encounter_class").alias("visit_source_value"),
)

condition_occurrence: DataFrame = condition.select(
    omop_id("condition_id").alias("condition_occurrence_id"),
    omop_id("patient_key").alias("person_id"),
    F.lit(0).alias("condition_concept_id"),
    F.to_date("onset_at").alias("condition_start_date"),
    F.col("onset_at").alias("condition_start_datetime"),
    F.to_date("abatement_at").alias("condition_end_date"),
    F.col("abatement_at").alias("condition_end_datetime"),
    F.lit(ehr_type_concept_id).alias("condition_type_concept_id"),
    omop_id("encounter_id").alias("visit_occurrence_id"),
    F.col("condition_code").alias("condition_source_value"),
    F.col("clinical_status").alias("condition_status_source_value"),
)

# OMOP puts labs and vital signs in measurement; surveys and social history belong in the observation table
measurement: DataFrame = observation.filter(F.col("category").isin("laboratory", "vital-signs")).select(
    omop_id("observation_id").alias("measurement_id"),
    omop_id("patient_key").alias("person_id"),
    F.lit(0).alias("measurement_concept_id"),
    F.to_date("effective_at").alias("measurement_date"),
    F.col("effective_at").alias("measurement_datetime"),
    F.lit(ehr_type_concept_id).alias("measurement_type_concept_id"),
    F.col("value_number").alias("value_as_number"),
    omop_id("encounter_id").alias("visit_occurrence_id"),
    F.col("observation_code").alias("measurement_source_value"),
    F.col("value_unit").alias("unit_source_value"),
    F.coalesce(F.col("value_number").cast("string"), F.col("value_text")).alias("value_source_value"),
)

omop_tables: Dict[str, DataFrame] = {
    "person": person,
    "visit_occurrence": visit_occurrence,
    "condition_occurrence": condition_occurrence,
    "measurement": measurement,
}

row_counts: Dict[str, int] = {}
for table_name, table_data in omop_tables.items():
    full_name: str = "synthea.omop." + table_name
    table_data.write.mode("overwrite").option("overwriteSchema", "true").saveAsTable(full_name)
    row_counts[table_name] = spark.table(full_name).count()

dbutils.notebook.exit(json.dumps(row_counts))
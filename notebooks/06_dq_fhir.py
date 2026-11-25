# Databricks notebook source
# Data quality checks on the FHIR silver tables.
# Every failing row goes to synthea.silver.fhir_dq_failure with the check name and severity,
# so bad rows are logged instead of silently dropped.
# error = data is wrong. warning = known source quirk, kept but flagged.
import json
from functools import reduce
from typing import Dict, List, Tuple

from pyspark.sql import DataFrame
from pyspark.sql import functions as F

patient: DataFrame = spark.table("synthea.silver.fhir_patient")
encounter: DataFrame = spark.table("synthea.silver.fhir_encounter")
condition: DataFrame = spark.table("synthea.silver.fhir_condition")
observation: DataFrame = spark.table("synthea.silver.fhir_observation")

patient_dates: DataFrame = patient.select("patient_key", "birth_date", "death_at")
encounter_with_patient: DataFrame = (
    encounter
        .join(patient_dates, "patient_key")
        .withColumn("start_date", F.to_date("start_at"))
)

# check name -> (severity, table checked, id column, failing rows)
checks: Dict[str, Tuple[str, str, str, DataFrame]] = {
    "missing_condition_code": (
        "error", "fhir_condition", "condition_id",
        condition.filter(F.col("condition_code").isNull() | (F.trim("condition_code") == "")),
    ),
    "encounter_without_patient": (
        "error", "fhir_encounter", "encounter_id",
        encounter.join(patient_dates, "patient_key", "left_anti"),
    ),
    "condition_without_patient": (
        "error", "fhir_condition", "condition_id",
        condition.join(patient_dates, "patient_key", "left_anti"),
    ),
    "observation_without_patient": (
        "error", "fhir_observation", "observation_id",
        observation.join(patient_dates, "patient_key", "left_anti"),
    ),
    # birth is a date only, visits have a time and timezone, so a visit on the birth day can land one day early
    "encounter_day_before_birth": (
        "warning", "fhir_encounter", "encounter_id",
        encounter_with_patient.filter(F.col("start_date") == F.date_sub("birth_date", 1)),
    ),
    "encounter_before_birth": (
        "error", "fhir_encounter", "encounter_id",
        encounter_with_patient.filter(F.col("start_date") < F.date_sub("birth_date", 1)),
    ),
    # Death Certification is paperwork done after death, not a visit
    "encounter_after_death": (
        "error", "fhir_encounter", "encounter_id",
        encounter_with_patient.filter(
            (F.col("start_at") > F.col("death_at"))
            & (F.col("encounter_display") != "Death Certification")
        ),
    ),
    "encounter_end_before_start": (
        "error", "fhir_encounter", "encounter_id",
        encounter.filter(F.col("end_at") < F.col("start_at")),
    ),
}

failure_frames: List[DataFrame] = []
for check_name, (severity, table_name, id_column, failing_rows) in checks.items():
    failure_frames.append(
        failing_rows.select(
            F.lit(check_name).alias("check_name"),
            F.lit(severity).alias("severity"),
            F.lit(table_name).alias("table_name"),
            F.col(id_column).alias("record_id"),
            F.col("patient_key"),
        )
    )

all_failures: DataFrame = (
    reduce(lambda left_frame, right_frame: left_frame.unionByName(right_frame), failure_frames)
        .withColumn("checked_at", F.current_timestamp())
)
all_failures.write.mode("overwrite").option("overwriteSchema", "true").saveAsTable("synthea.silver.fhir_dq_failure")

failure_counts: Dict[str, int] = {}
for check_name in checks:
    failure_counts[check_name] = 0
for count_row in spark.table("synthea.silver.fhir_dq_failure").groupBy("check_name").count().collect():
    failure_counts[count_row["check_name"]] = count_row["count"]

dbutils.notebook.exit(json.dumps(failure_counts))
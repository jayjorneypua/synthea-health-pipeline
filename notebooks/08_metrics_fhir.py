# Databricks notebook source
# Healthcare metrics from the OMOP tables, written to synthea.gold for Power BI.
# Readmission: inpatient stay followed by another inpatient admission within 30 days of discharge.
# Length of stay: discharge minus admit, in days, inpatient stays only.
# Chronic condition: a SNOMED disorder that is still open or lasted 365 days or more.
import json
from typing import Dict, List

spark.sql("CREATE SCHEMA IF NOT EXISTS synthea.gold")

metric_statements: List[str] = [
    """
    CREATE OR REPLACE TABLE synthea.gold.fhir_inpatient_stay AS
    WITH inpatient AS (
        SELECT
            visit_occurrence_id
            , person_id
            , visit_start_datetime
            , visit_end_datetime
            , LEAD(visit_start_datetime) OVER (PARTITION BY person_id ORDER BY visit_start_datetime) AS next_admit_datetime
        FROM
            synthea.omop.visit_occurrence
        WHERE
            visit_concept_id = 9201
    )
    SELECT
        visit_occurrence_id
        , person_id
        , visit_start_datetime AS admit_datetime
        , visit_end_datetime AS discharge_datetime
        , (UNIX_TIMESTAMP(visit_end_datetime) - UNIX_TIMESTAMP(visit_start_datetime)) / 86400.0 AS length_of_stay_days
        , CASE WHEN next_admit_datetime <= visit_end_datetime + INTERVAL 30 DAYS THEN 1 ELSE 0 END AS readmitted_30d
    FROM
        inpatient
    """,
    """
    CREATE OR REPLACE TABLE synthea.gold.fhir_inpatient_by_year AS
    SELECT
        YEAR(discharge_datetime) AS discharge_year
        , COUNT(*) AS inpatient_stays
        , SUM(readmitted_30d) AS readmissions_30d
        , ROUND(SUM(readmitted_30d) / COUNT(*), 4) AS readmission_rate
        , ROUND(AVG(length_of_stay_days), 2) AS avg_length_of_stay_days
    FROM
        synthea.gold.fhir_inpatient_stay
    GROUP BY
        YEAR(discharge_datetime)
    """,
    """
    CREATE OR REPLACE TABLE synthea.gold.fhir_chronic_condition AS
    WITH condition_name AS (
        SELECT
            condition_code
            , MAX(condition_display) AS condition_display
        FROM
            synthea.silver.fhir_condition
        GROUP BY
            condition_code
    )
    SELECT
        occurrence.person_id
        , occurrence.condition_source_value AS condition_code
        , condition_name.condition_display
    FROM
        synthea.omop.condition_occurrence AS occurrence
        JOIN condition_name
            ON condition_name.condition_code = occurrence.condition_source_value
    WHERE
        condition_name.condition_display LIKE '%(disorder)%'
        AND (
            occurrence.condition_end_date IS NULL
            OR DATEDIFF(occurrence.condition_end_date, occurrence.condition_start_date) >= 365
        )
    GROUP BY
        occurrence.person_id
        , occurrence.condition_source_value
        , condition_name.condition_display
    """,
    """
    CREATE OR REPLACE TABLE synthea.gold.fhir_chronic_per_patient AS
    SELECT
        person.person_id
        , person.gender_source_value AS gender
        , person.year_of_birth
        , COUNT(chronic.condition_code) AS chronic_condition_count
    FROM
        synthea.omop.person AS person
        LEFT JOIN synthea.gold.fhir_chronic_condition AS chronic
            ON chronic.person_id = person.person_id
    GROUP BY
        person.person_id
        , person.gender_source_value
        , person.year_of_birth
    """,
]

for metric_statement in metric_statements:
    spark.sql(metric_statement)

stay_summary = spark.sql("""
    SELECT
        COUNT(*) AS inpatient_stays
        , ROUND(SUM(readmitted_30d) / COUNT(*), 4) AS readmission_rate
        , ROUND(AVG(length_of_stay_days), 2) AS avg_length_of_stay_days
    FROM
        synthea.gold.fhir_inpatient_stay
""").first()

chronic_summary = spark.sql("""
    SELECT
        ROUND(AVG(chronic_condition_count), 2) AS avg_chronic_per_patient
    FROM
        synthea.gold.fhir_chronic_per_patient
""").first()

summary: Dict[str, float] = {
    "inpatient_stays": stay_summary["inpatient_stays"],
    "readmission_rate": float(stay_summary["readmission_rate"] or 0),
    "avg_length_of_stay_days": float(stay_summary["avg_length_of_stay_days"] or 0),
    "avg_chronic_per_patient": float(chronic_summary["avg_chronic_per_patient"] or 0),
}
dbutils.notebook.exit(json.dumps(summary))
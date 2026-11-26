"""synthea_health_pipeline: generate -> load stage -> merge -> simulate -> extract -> Databricks job -> cleanup.

FHIR path in the same run: generate also writes FHIR bundles, upload_fhir sends them to the
fhir volume (deleting each local file after a verified upload), and the Databricks job runs the
FHIR notebooks next to the CDC ones.

Manual trigger only (schedule=None). Every step is a script that also runs on its own outside Airflow.
Cleanup only runs after the Databricks job succeeded, so local CSVs are kept for a rerun if anything fails.
"""
from datetime import datetime

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG

PROJECT: str = "/opt/project"
PYTHON: str = "/opt/pipeline/bin/python"

with DAG(
    dag_id="synthea_health_pipeline",
    schedule=None,
    start_date=datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["synthea"],
) as dag:
    # FHIR: only the resource types the pipeline uses, UUID file names so patient names never leave this machine
    generate = BashOperator(
        task_id="generate_synthea",
        bash_command=(
            "cd " + PROJECT + " && rm -rf data/synthea/csv data/synthea/fhir && "
            "java -jar synthea/synthea-with-dependencies.jar -s 42 -r 20261122 -p 1000 "
            "--exporter.baseDirectory ./data/synthea/ --exporter.csv.export true "
            "--exporter.fhir.export true --exporter.fhir.included_resources Patient,Encounter,Condition,Observation "
            "--exporter.hospital.fhir.export false --exporter.practitioner.fhir.export false "
            "--exporter.use_uuid_filenames true"
        ),
    )

    upload_fhir = BashOperator(
        task_id="upload_fhir",
        bash_command="cd " + PROJECT + " && " + PYTHON + " extractor/upload_fhir.py",
    )

    load_stage = BashOperator(
        task_id="load_stage",
        bash_command="cd " + PROJECT + " && " + PYTHON + " loader/load_stage.py",
    )

    merge = BashOperator(
        task_id="sp_load_all",
        bash_command="cd " + PROJECT + " && " + PYTHON + " orchestration/run_proc.py stage.spLoad_All",
    )

    # sleep: give the CDC capture job (polls every 5s) time to log the changes before extracting
    simulate = BashOperator(
        task_id="simulate_changes",
        bash_command="cd " + PROJECT + " && " + PYTHON + " orchestration/run_proc.py stage.spSimulate_Changes && sleep 15",
    )

    extract = BashOperator(
        task_id="extract_cdc",
        bash_command="cd " + PROJECT + " && " + PYTHON + " extractor/extract_cdc.py",
    )

    databricks_job = BashOperator(
        task_id="run_databricks_job",
        bash_command="cd " + PROJECT + " && " + PYTHON + " orchestration/run_databricks_job.py",
    )

    cleanup = BashOperator(
        task_id="cleanup_local_files",
        bash_command="cd " + PROJECT + " && rm -rf data/synthea/csv data/synthea/fhir data/extract",
    )

    generate >> [load_stage, upload_fhir]
    load_stage >> merge >> simulate >> extract
    [extract, upload_fhir] >> databricks_job >> cleanup
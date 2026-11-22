"""synthea_health_pipeline: generate -> load stage -> merge -> simulate -> extract -> Databricks job -> cleanup.

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
    generate = BashOperator(
        task_id="generate_synthea",
        bash_command=(
            "cd " + PROJECT + " && rm -rf data/synthea/csv && "
            "java -jar synthea/synthea-with-dependencies.jar -s 42 -p 100 "
            "--exporter.baseDirectory ./data/synthea/ --exporter.csv.export true --exporter.fhir.export false"
        ),
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
        bash_command="cd " + PROJECT + " && rm -rf data/synthea/csv data/extract",
    )

    generate >> load_stage >> merge >> simulate >> extract >> databricks_job >> cleanup
"""Triggers the synthea_health_pipeline Databricks job, waits for it, and fails if the run fails.

Auth: DATABRICKS_HOST + DATABRICKS_TOKEN env vars (Docker), otherwise the CLI profile.
"""
import argparse
import os
import sys
from datetime import timedelta
from typing import List

from databricks.sdk import WorkspaceClient
from databricks.sdk.service.jobs import BaseJob, Run

JOB_NAME: str = "synthea_health_pipeline"


def main() -> int:
    parser: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", default=os.environ.get("DATABRICKS_CONFIG_PROFILE", "dbc-609647e1-c073"))
    args: argparse.Namespace = parser.parse_args()

    client: WorkspaceClient
    if os.environ.get("DATABRICKS_TOKEN") is not None:
        client = WorkspaceClient()
    else:
        client = WorkspaceClient(profile=args.profile)

    jobs: List[BaseJob] = list(client.jobs.list(name=JOB_NAME))
    if len(jobs) != 1:
        raise RuntimeError("Expected 1 job named " + JOB_NAME + ", found " + str(len(jobs)))

    print("triggering " + JOB_NAME + " (job " + str(jobs[0].job_id) + ")")
    try:
        run: Run = client.jobs.run_now(job_id=jobs[0].job_id).result(timeout=timedelta(minutes=30))
    except Exception as error:
        print("job run failed: " + str(error))
        return 1

    print("run " + str(run.run_id) + ": " + str(run.state.result_state) + " " + str(run.run_page_url))
    if str(run.state.result_state) != "RunResultState.SUCCESS":
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
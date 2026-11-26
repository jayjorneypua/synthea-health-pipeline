"""Uploads the Synthea FHIR bundles to a Databricks volume.

Each JSON file in data/synthea/fhir goes to /Volumes/synthea/landing/fhir/bundles/, its size is
verified, and only then the local file is deleted, so the bundles never pile up on disk.
Bronze (04_bronze_fhir) picks them up with Auto Loader.
"""
import argparse
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import List, Optional

from databricks.sdk import WorkspaceClient

VOLUME_ROOT: str = "/Volumes/synthea/landing/fhir/bundles"
LOCAL_ROOT: Path = Path(__file__).resolve().parent.parent / "data" / "synthea" / "fhir"
UPLOAD_THREADS: int = 8


def upload_and_delete(client: WorkspaceClient, local_path: Path) -> None:
    remote_path: str = VOLUME_ROOT + "/" + local_path.name
    with open(local_path, "rb") as handle:
        client.files.upload(remote_path, handle, overwrite=True)
    remote_size: Optional[int] = client.files.get_metadata(remote_path).content_length
    local_size: int = local_path.stat().st_size
    if remote_size != local_size:
        raise RuntimeError("Size mismatch for " + remote_path + ": local " + str(local_size) + ", remote " + str(remote_size))
    local_path.unlink()


def main() -> int:
    parser: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", default=os.environ.get("DATABRICKS_CONFIG_PROFILE", "dbc-609647e1-c073"))
    args: argparse.Namespace = parser.parse_args()

    if LOCAL_ROOT.is_dir() == False:
        print("FHIR folder not found: " + str(LOCAL_ROOT))
        return 1

    client: WorkspaceClient
    if os.environ.get("DATABRICKS_TOKEN") is not None:
        client = WorkspaceClient()  # DATABRICKS_HOST + DATABRICKS_TOKEN from env (Docker)
    else:
        client = WorkspaceClient(profile=args.profile)

    bundle_files: List[Path] = sorted(LOCAL_ROOT.glob("*.json"))
    if len(bundle_files) == 0:
        print("no FHIR files in " + str(LOCAL_ROOT))
        return 1

    started: float = time.perf_counter()
    with ThreadPoolExecutor(max_workers=UPLOAD_THREADS) as pool:
        list(pool.map(lambda local_path: upload_and_delete(client, local_path), bundle_files))

    seconds: float = time.perf_counter() - started
    print("uploaded " + str(len(bundle_files)) + " FHIR bundles in " + str(round(seconds, 1)) + "s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
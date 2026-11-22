"""Extracts CDC changes from SyntheaHealth to Parquet and uploads them to a Databricks volume.

Per capture instance:
- No watermark yet, or the change data was purged past the watermark: full snapshot of the
  source table (_op = S), because change tables only hold changes made after CDC was enabled.
- Otherwise: net changes since the watermark (_op = I, U or D).
Every file is uploaded to /Volumes/synthea/landing/cdc/<instance>/, its size is verified, the
local file is deleted, and only then the watermark is saved. A crash before the watermark save
means the next run re-extracts the same changes; silver must be idempotent (it is: upsert by key).

Runs as the synthea_extractor SQL login (password in env var SYNTHEA_EXTRACTOR_PWD). Masked PII
stays masked; BirthDate is unmasked for this login only.
"""
import argparse
import os
import re
import sys
import time
from datetime import date, datetime, timezone
from decimal import Decimal
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import pyarrow as pa
import pyarrow.parquet as pq
import pyodbc
from databricks.sdk import WorkspaceClient

VOLUME_ROOT: str = "/Volumes/synthea/landing/cdc"
LOCAL_ROOT: Path = Path(__file__).resolve().parent.parent / "data" / "extract"
OPERATION_CODES: Dict[int, str] = {1: "D", 2: "I", 4: "U"}
SAFE_NAME: re.Pattern = re.compile(r"^\w+$")


def pick_driver() -> str:
    preferred: List[str] = ["ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server"]
    installed: List[str] = pyodbc.drivers()
    for name in preferred:
        if name in installed:
            return name
    raise RuntimeError("No SQL Server ODBC driver found. Installed: " + ", ".join(installed))


def connect(server: str, database: str) -> pyodbc.Connection:
    password: Optional[str] = os.environ.get("SYNTHEA_EXTRACTOR_PWD")
    if password is None or password == "":
        raise RuntimeError("SYNTHEA_EXTRACTOR_PWD is not set (restart VS Code after creating it)")
    driver: str = pick_driver()
    conn_str: str = (
        "Driver={" + driver + "};Server=" + server + ";Database=" + database + ";"
        "UID=synthea_extractor;PWD={" + password + "};Encrypt=yes;TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str, autocommit=False)


def arrow_type(type_code: Any, precision: Optional[int], scale: Optional[int]) -> pa.DataType:
    """Maps a pyodbc column type to an explicit Arrow type, so all-NULL columns keep their type."""
    if type_code == str:
        return pa.string()
    if type_code == bool:
        return pa.bool_()
    if type_code == int:
        return pa.int64()
    if type_code == float:
        return pa.float64()
    if type_code == Decimal:
        return pa.decimal128(precision, scale)
    if type_code == datetime:
        return pa.timestamp("us")
    if type_code == date:
        return pa.date32()
    if type_code == bytes or type_code == bytearray:
        return pa.binary()
    raise RuntimeError("Unmapped column type: " + str(type_code))


def build_table(cursor: pyodbc.Cursor, snapshot_lsn: bytes, extracted_at: datetime) -> pa.Table:
    """Reads all rows of the executed query into an Arrow table plus _op, _lsn, _extracted_at."""
    names: List[str] = []
    types: List[pa.DataType] = []
    for column in cursor.description:
        names.append(column[0])
        types.append(arrow_type(column[1], column[4], column[5]))
    rows: List[pyodbc.Row] = cursor.fetchall()

    lsn_index: int = -1
    op_index: int = -1
    data_columns: List[int] = []
    for index, name in enumerate(names):
        if name == "__$start_lsn":
            lsn_index = index
        elif name == "__$operation":
            op_index = index
        elif name.startswith("__$"):
            continue
        else:
            data_columns.append(index)

    arrays: Dict[str, pa.Array] = {}
    for index in data_columns:
        arrays[names[index]] = pa.array([row[index] for row in rows], type=types[index])

    ops: List[str] = []
    lsns: List[str] = []
    for row in rows:
        if op_index == -1:
            ops.append("S")
            lsns.append(snapshot_lsn.hex())
        else:
            ops.append(OPERATION_CODES[row[op_index]])
            lsns.append(row[lsn_index].hex())

    arrays["_op"] = pa.array(ops, type=pa.string())
    arrays["_lsn"] = pa.array(lsns, type=pa.string())
    arrays["_extracted_at"] = pa.array([extracted_at] * len(rows), type=pa.timestamp("us", tz="UTC"))
    return pa.table(arrays)


def get_watermark(cursor: pyodbc.Cursor, instance: str) -> Tuple[bool, Optional[bytes]]:
    cursor.execute("SELECT LastLsn FROM etl.CdcWatermark WHERE CaptureInstance = ? AND ID > 0", instance)
    row: Optional[pyodbc.Row] = cursor.fetchone()
    if row is None:
        return (False, None)
    return (True, row[0])


def save_watermark(cursor: pyodbc.Cursor, instance: str, exists: bool, lsn: bytes, row_count: int) -> None:
    if exists:
        cursor.execute(
            "UPDATE etl.CdcWatermark SET LastLsn = ?, LastRunDate = SYSUTCDATETIME(), LastRowCount = ?, "
            "ID_UpdatedBy = 1, UpdatedDate = SYSUTCDATETIME() WHERE CaptureInstance = ? AND ID > 0",
            lsn, row_count, instance,
        )
    else:
        cursor.execute(
            "INSERT INTO etl.CdcWatermark (CaptureInstance, LastLsn, LastRunDate, LastRowCount) "
            "VALUES (?, ?, SYSUTCDATETIME(), ?)",
            instance, lsn, row_count,
        )


def upload(client: WorkspaceClient, local_path: Path, remote_path: str) -> None:
    with open(local_path, "rb") as handle:
        client.files.upload(remote_path, handle, overwrite=False)
    remote_size: Optional[int] = client.files.get_metadata(remote_path).content_length
    local_size: int = local_path.stat().st_size
    if remote_size != local_size:
        raise RuntimeError("Size mismatch for " + remote_path + ": local " + str(local_size) + ", remote " + str(remote_size))


def extract_instance(
    conn: pyodbc.Connection, client: WorkspaceClient, instance: str, schema: str, table: str,
    max_lsn: bytes, run_id: str, extracted_at: datetime,
) -> None:
    started: float = time.perf_counter()
    cursor: pyodbc.Cursor = conn.cursor()

    exists: bool
    last_lsn: Optional[bytes]
    exists, last_lsn = get_watermark(cursor, instance)

    cursor.execute("SELECT sys.fn_cdc_get_min_lsn(?)", instance)
    min_lsn: bytes = cursor.fetchone()[0]

    mode: str = "cdc"
    if last_lsn is None:
        mode = "snapshot"
    elif last_lsn < min_lsn:
        print(instance + ": change data purged past the watermark, taking a new snapshot")
        mode = "snapshot"

    if mode == "snapshot":
        cursor.execute("SELECT * FROM [" + schema + "].[" + table + "]")
    else:
        cursor.execute("SELECT sys.fn_cdc_increment_lsn(?)", last_lsn)
        from_lsn: bytes = cursor.fetchone()[0]
        if from_lsn > max_lsn:
            print(instance + ": no changes")
            return
        cursor.execute("SELECT * FROM cdc.fn_cdc_get_net_changes_" + instance + "(?, ?, N'all')", from_lsn, max_lsn)

    arrow_table: pa.Table = build_table(cursor, max_lsn, extracted_at)
    row_count: int = arrow_table.num_rows

    if row_count > 0:
        file_name: str = instance + "_" + run_id + "_" + mode + ".parquet"
        local_dir: Path = LOCAL_ROOT / instance
        local_dir.mkdir(parents=True, exist_ok=True)
        local_path: Path = local_dir / file_name
        pq.write_table(arrow_table, local_path, compression="snappy")
        upload(client, local_path, VOLUME_ROOT + "/" + instance + "/" + file_name)
        local_path.unlink()

    save_watermark(cursor, instance, exists, max_lsn, row_count)
    conn.commit()

    seconds: float = time.perf_counter() - started
    print(instance + ": " + mode + " " + str(row_count) + " rows in " + str(round(seconds, 1)) + "s")


def main() -> int:
    parser: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--server", default=os.environ.get("SYNTHEA_SQL_SERVER", "."))
    parser.add_argument("--database", default="SyntheaHealth")
    parser.add_argument("--profile", default=os.environ.get("DATABRICKS_CONFIG_PROFILE", "dbc-609647e1-c073"))
    args: argparse.Namespace = parser.parse_args()

    pyodbc.native_uuid = False  # UNIQUEIDENTIFIER as string in Parquet
    client: WorkspaceClient = WorkspaceClient(profile=args.profile)
    conn: pyodbc.Connection = connect(args.server, args.database)

    try:
        cursor: pyodbc.Cursor = conn.cursor()
        cursor.execute("SELECT sys.fn_cdc_get_max_lsn()")
        max_lsn: Optional[bytes] = cursor.fetchone()[0]
        if max_lsn is None:
            raise RuntimeError("CDC max LSN is NULL: is SQL Server Agent running?")

        cursor.execute(
            "SELECT capture_instance, OBJECT_SCHEMA_NAME(source_object_id), OBJECT_NAME(source_object_id) "
            "FROM cdc.change_tables ORDER BY capture_instance"
        )
        instances: List[pyodbc.Row] = cursor.fetchall()
        conn.commit()

        extracted_at: datetime = datetime.now(timezone.utc)
        run_id: str = extracted_at.strftime("%Y%m%dT%H%M%SZ")
        print("run " + run_id + ", max LSN " + max_lsn.hex() + ", " + str(len(instances)) + " capture instances")

        for row in instances:
            instance: str = row[0]
            if SAFE_NAME.match(instance) is None:
                raise RuntimeError("Unexpected capture instance name: " + instance)
            extract_instance(conn, client, instance, row[1], row[2], max_lsn, run_id, extracted_at)
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    print("extract done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
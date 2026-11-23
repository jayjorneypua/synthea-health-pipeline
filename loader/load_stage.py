"""Loads Synthea CSV files into the stage tables of SyntheaHealth.

Each run clears a stage table and refills it from its CSV. Only columns that exist in both
the CSV header and the stage table are loaded, so CSV columns we never store (SSN, passport,
driver's license) are skipped. The merge procs then move stage rows into the real tables.
"""
import argparse
import csv
import os
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pyodbc

# CSV file name -> stage table name, in load order
FILE_TO_TABLE: Dict[str, str] = {
    "payers.csv": "Payer",
    "organizations.csv": "Organization",
    "providers.csv": "Provider",
    "patients.csv": "Patient",
    "encounters.csv": "Encounter",
    "conditions.csv": "Condition",
    "medications.csv": "Medication",
    "procedures.csv": "Procedure",
    "claims.csv": "Claim",
    "claims_transactions.csv": "ClaimLine",
}
BATCH_SIZE: int = 5000


def pick_driver() -> str:
    preferred: List[str] = ["ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server"]
    installed: List[str] = pyodbc.drivers()
    for name in preferred:
        if name in installed:
            return name
    raise RuntimeError("No SQL Server ODBC driver found. Installed: " + ", ".join(installed))


def connect(server: str, database: str) -> pyodbc.Connection:
    """synthea_loader SQL login when SYNTHEA_LOADER_PWD is set (least privilege, works in Docker),
    otherwise Windows authentication."""
    driver: str = pick_driver()
    password: Optional[str] = os.environ.get("SYNTHEA_LOADER_PWD")
    auth: str = "Trusted_Connection=yes;"
    if password is not None and password != "":
        auth = "UID=synthea_loader;PWD={" + password + "};"
    conn_str: str = (
        "Driver={" + driver + "};Server=" + server + ";Database=" + database + ";"
        + auth + "Encrypt=yes;TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str, autocommit=False)


def get_stage_columns(cursor: pyodbc.Cursor, table: str) -> List[Tuple[str, int]]:
    """Returns (column name, max length) for the stage table, without StageID."""
    cursor.execute(
        "SELECT COLUMN_NAME, CHARACTER_MAXIMUM_LENGTH "
        "FROM INFORMATION_SCHEMA.COLUMNS "
        "WHERE TABLE_SCHEMA = 'stage' AND TABLE_NAME = ? AND COLUMN_NAME <> 'StageID' "
        "ORDER BY ORDINAL_POSITION",
        table,
    )
    columns: List[Tuple[str, int]] = []
    for row in cursor.fetchall():
        columns.append((str(row[0]), int(row[1])))
    return columns


def to_value(text: str) -> Optional[str]:
    if text == "":
        return None
    return text


def load_file(conn: pyodbc.Connection, csv_path: Path, table: str) -> int:
    cursor: pyodbc.Cursor = conn.cursor()
    cursor.fast_executemany = True

    stage_columns: List[Tuple[str, int]] = get_stage_columns(cursor, table)
    if len(stage_columns) == 0:
        raise RuntimeError("Stage table stage." + table + " not found or has no columns.")

    total: int = 0
    with csv_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.reader(handle)
        header: List[str] = next(reader)

        # columns present in both the stage table and the CSV, in stage order
        positions: List[int] = []
        names: List[str] = []
        sizes: List[Tuple[int, int, int]] = []
        for name, length in stage_columns:
            if name in header:
                positions.append(header.index(name))
                names.append(name)
                sizes.append((pyodbc.SQL_WVARCHAR, length, 0))
            else:
                print("  warning: " + csv_path.name + " has no column " + name + " (left NULL)")

        column_list: str = ", ".join("[" + name + "]" for name in names)
        placeholders: str = ", ".join("?" for _ in names)
        insert_sql: str = "INSERT INTO stage.[" + table + "] (" + column_list + ") VALUES (" + placeholders + ")"

        cursor.execute("DELETE FROM stage.[" + table + "]")
        cursor.setinputsizes(sizes)

        batch: List[List[Optional[str]]] = []
        line_number: int = 1
        for row in reader:
            line_number = line_number + 1
            if len(row) < len(header):
                raise RuntimeError(csv_path.name + " line " + str(line_number) + " has too few columns.")
            values: List[Optional[str]] = []
            for position in positions:
                values.append(to_value(row[position]))
            batch.append(values)
            if len(batch) >= BATCH_SIZE:
                cursor.executemany(insert_sql, batch)
                total = total + len(batch)
                batch = []

        if len(batch) > 0:
            cursor.executemany(insert_sql, batch)
            total = total + len(batch)

    conn.commit()
    return total


def main() -> int:
    parser = argparse.ArgumentParser(description="Load Synthea CSV files into stage tables.")
    parser.add_argument("--csv-dir", default="data/synthea/csv")
    parser.add_argument("--server", default=os.environ.get("SYNTHEA_SQL_SERVER", "."))
    parser.add_argument("--database", default="SyntheaHealth")
    args = parser.parse_args()

    csv_dir: Path = Path(args.csv_dir)
    if csv_dir.is_dir() == False:
        print("CSV folder not found: " + str(csv_dir))
        return 1

    conn: pyodbc.Connection = connect(args.server, args.database)
    started: float = time.perf_counter()
    try:
        for file_name, table in FILE_TO_TABLE.items():
            csv_path: Path = csv_dir / file_name
            if csv_path.is_file() == False:
                raise RuntimeError("Missing file: " + str(csv_path))
            file_started: float = time.perf_counter()
            rows: int = load_file(conn, csv_path, table)
            seconds: float = time.perf_counter() - file_started
            print("stage.{0}: {1} rows in {2:.1f}s".format(table, rows, seconds))
    except Exception as error:
        conn.rollback()
        print("load failed: " + str(error))
        return 1
    finally:
        conn.close()

    print("stage load done in {0:.1f}s".format(time.perf_counter() - started))
    return 0


if __name__ == "__main__":
    sys.exit(main())
"""Runs one allowed stored proc in SyntheaHealth as the synthea_loader login and prints its PRINT output.

Usage: python orchestration/run_proc.py stage.spLoad_All
"""
import argparse
import os
import sys
from typing import List, Optional

import pyodbc

ALLOWED_PROCS: List[str] = ["stage.spLoad_All", "stage.spSimulate_Changes"]


def pick_driver() -> str:
    preferred: List[str] = ["ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server"]
    installed: List[str] = pyodbc.drivers()
    for name in preferred:
        if name in installed:
            return name
    raise RuntimeError("No SQL Server ODBC driver found. Installed: " + ", ".join(installed))


def main() -> int:
    parser: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("proc", choices=ALLOWED_PROCS)
    parser.add_argument("--server", default=os.environ.get("SYNTHEA_SQL_SERVER", "."))
    parser.add_argument("--database", default="SyntheaHealth")
    args: argparse.Namespace = parser.parse_args()

    password: Optional[str] = os.environ.get("SYNTHEA_LOADER_PWD")
    if password is None or password == "":
        raise RuntimeError("SYNTHEA_LOADER_PWD is not set")

    conn_str: str = (
        "Driver={" + pick_driver() + "};Server=" + args.server + ";Database=" + args.database + ";"
        "UID=synthea_loader;PWD={" + password + "};Encrypt=yes;TrustServerCertificate=yes;"
    )
    conn: pyodbc.Connection = pyodbc.connect(conn_str, autocommit=True)
    try:
        cursor: pyodbc.Cursor = conn.cursor()
        cursor.execute("EXEC " + args.proc)
        # PRINT output arrives as messages, one result set at a time
        while True:
            for message in cursor.messages:
                print(str(message[1]).split("]")[-1])
            more: bool = cursor.nextset()
            if more == False:
                break
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
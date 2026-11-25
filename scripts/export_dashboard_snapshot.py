"""
Exports the MARTS tables used by the dashboard to Parquet files in
dashboard/snapshot/, so the public version (Streamlit Community Cloud) works
without a Snowflake connection.

Usage (from the project root):
    pip install -r requirements-dev.txt
    python scripts/export_dashboard_snapshot.py

Uses a Snowflake CLI connection from ~/.snowflake/config.toml
(default: racing_dev; override with SNOWFLAKE_CONNECTION).
"""
import json
import os
from datetime import datetime, timezone
from pathlib import Path

import snowflake.connector

CONNECTION_NAME = os.getenv("SNOWFLAKE_CONNECTION", "racing_dev")
SNAPSHOT_DIR = Path("dashboard/snapshot")
TABLES = ["fct_race_conditions", "fct_heat_event_validation"]


def main():
    SNAPSHOT_DIR.mkdir(parents=True, exist_ok=True)
    conn = snowflake.connector.connect(connection_name=CONNECTION_NAME)
    try:
        cur = conn.cursor()
        for table in TABLES:
            cur.execute(f"select * from MARTS.{table.upper()}")
            df = cur.fetch_pandas_all()
            df.columns = [c.lower() for c in df.columns]
            out_file = SNAPSHOT_DIR / f"{table}.parquet"
            df.to_parquet(out_file, index=False)
            print(f"{table}: {len(df):,} rows -> {out_file}")
        database = conn.database
    finally:
        conn.close()

    metadata = {
        "exported_at": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "source": f"{database}.MARTS",
        "tables": TABLES,
    }
    (SNAPSHOT_DIR / "metadata.json").write_text(json.dumps(metadata, indent=2))
    print("Done.")


if __name__ == "__main__":
    main()

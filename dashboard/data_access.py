"""
Data access for the dashboard.

- Inside Streamlit in Snowflake: reads the MARTS tables live through the
  active Snowpark session (the app runs with its owner's role).
- Anywhere else (local run, Streamlit Community Cloud): reads the Parquet
  snapshot in dashboard/snapshot/, exported by scripts/export_dashboard_snapshot.py.

Column names are lower-cased in both cases so the app code is identical.
"""
import json
from pathlib import Path

import pandas as pd
import streamlit as st

SNAPSHOT_DIR = Path(__file__).parent / "snapshot"


def _get_snowflake_session():
    """Return the active Snowpark session when running in Snowflake, else None."""
    try:
        from snowflake.snowpark.context import get_active_session

        return get_active_session()
    except Exception:
        return None


@st.cache_data(show_spinner="Loading data...")
def load_table(table_name: str) -> pd.DataFrame:
    """Load a MARTS table (live in Snowflake, snapshot elsewhere)."""
    session = _get_snowflake_session()
    if session is not None:
        df = session.table(f"MARTS.{table_name.upper()}").to_pandas()
    else:
        df = pd.read_parquet(SNAPSHOT_DIR / f"{table_name}.parquet")
    df.columns = [c.lower() for c in df.columns]
    return df


def data_source_label() -> str:
    """Human-readable description of where the data comes from."""
    if _get_snowflake_session() is not None:
        return "Live data from Snowflake (MARTS layer)"
    metadata_file = SNAPSHOT_DIR / "metadata.json"
    if metadata_file.exists():
        metadata = json.loads(metadata_file.read_text())
        return f"Snapshot of the MARTS layer exported on {metadata.get('exported_at', 'unknown date')}"
    return "Snapshot of the MARTS layer"

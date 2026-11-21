"""
Builds the NSW track seed template from all Betfair CSV files.

Usage (from the project root):
    python scripts/build_track_seed_template.py

Output:
    dbt/seeds/seed_tracks.csv  -> fill in latitude / longitude manually

If the seed already exists it is NOT overwritten: the script only reports
tracks that appear in the Betfair data but are missing from the seed.
"""
from pathlib import Path

import pandas as pd

RAW_DIR = Path("data/raw/betfair")
OUT_FILE = Path("dbt/seeds/seed_tracks.csv")
STATE = "NSW"

# Date formats found in the Betfair files:
#   - ISO (YYYY-MM-DD): most files
#   - DD/MM/YYYY: ANZ_Thoroughbreds_2025_04.csv (most likely edited in Excel)
DATE_FORMATS = ["%Y-%m-%d", "%d/%m/%Y"]


def parse_mixed_dates(s: pd.Series) -> pd.Series:
    """Try each format in order and keep the first one that parses.
    Same logic as coalesce(try_to_date(...), ...) in the STAGING model."""
    result = pd.Series(pd.NaT, index=s.index)
    for fmt in DATE_FORMATS:
        parsed = pd.to_datetime(s, format=fmt, errors="coerce")
        result = result.fillna(parsed)
    return result


files = sorted(RAW_DIR.glob("ANZ_Thoroughbreds_*.csv"))
print(f"Reading {len(files)} files...")

cols = ["LOCAL_MEETING_DATE", "TRACK", "STATE_CODE", "WIN_MARKET_ID"]
df = pd.concat(
    (pd.read_csv(f, usecols=cols, dtype={"LOCAL_MEETING_DATE": str}) for f in files),
    ignore_index=True,
)

# --- Date parsing --------------------------------------------------------------
df["meeting_date"] = parse_mixed_dates(df["LOCAL_MEETING_DATE"])

unparsed = df[df["meeting_date"].isna()]["LOCAL_MEETING_DATE"].unique()
if len(unparsed) > 0:
    raise ValueError(
        f"{len(unparsed)} dates in an unknown format. Examples: {unparsed[:10]}"
    )
print("All dates parsed successfully.")
# -------------------------------------------------------------------------------

nsw = df[df["STATE_CODE"] == STATE]

tracks = (
    nsw.groupby("TRACK")
    .agg(
        n_races=("WIN_MARKET_ID", "nunique"),
        n_meetings=("meeting_date", "nunique"),
        first_meeting=("meeting_date", "min"),
        last_meeting=("meeting_date", "max"),
    )
    .sort_values("n_races", ascending=False)
    .reset_index()
    .rename(columns={"TRACK": "betfair_track_name"})
)
tracks["first_meeting"] = tracks["first_meeting"].dt.date
tracks["last_meeting"] = tracks["last_meeting"].dt.date

print(f"\n{len(tracks)} tracks in {STATE}:\n")
print(tracks.to_string(index=False))

# Seed template: only the columns that go to dbt
seed = tracks[["betfair_track_name"]].copy()
seed["track_name"] = seed["betfair_track_name"]  # official name, editable
seed["latitude"] = None
seed["longitude"] = None
seed["timezone"] = "Australia/Sydney"

OUT_FILE.parent.mkdir(parents=True, exist_ok=True)

if OUT_FILE.exists():
    # Never overwrite the hand-curated seed: only report new tracks
    existing = pd.read_csv(OUT_FILE)
    new_tracks = sorted(set(seed["betfair_track_name"]) - set(existing["betfair_track_name"]))
    if new_tracks:
        print(f"\n⚠️  New tracks not yet in {OUT_FILE}: {new_tracks}")
        print("    Add them manually with their coordinates.")
    else:
        print(f"\n{OUT_FILE} already exists and is complete. Not modified.")
else:
    seed.to_csv(OUT_FILE, index=False)
    print(f"\nTemplate saved to {OUT_FILE} -> fill in latitude/longitude")

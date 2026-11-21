"""
Downloads historical hourly weather from Open-Meteo for every track in the seed.

Usage (from the project root):
    pip install -r requirements.txt
    python scripts/fetch_weather.py

Output:
    data/raw/weather/<track>.csv  (one file per track, times in UTC)

Design notes:
- Times are requested in UTC (timezone=GMT) to avoid daylight-saving
  ambiguities. Conversion to local time happens in dbt.
- The historical archive (ERA5) lags a few days behind, so END_DATE is
  today minus 7 days.
- Data is downloaded one year at a time to avoid overly long requests.
- If a track's CSV already exists it is skipped, so the script can resume
  after an interruption.
"""
import time
from datetime import date, timedelta
from pathlib import Path

import pandas as pd
import requests

SEED_FILE = Path("dbt/seeds/seed_tracks.csv")
OUT_DIR = Path("data/raw/weather")
API_URL = "https://archive-api.open-meteo.com/v1/archive"

START_DATE = date(2023, 1, 1)
END_DATE = date.today() - timedelta(days=7)

HOURLY_VARS = [
    "temperature_2m",        # °C
    "relative_humidity_2m",  # %
    "dew_point_2m",          # °C
    "apparent_temperature",  # °C (feels-like temperature)
    "wind_speed_10m",        # km/h
    "shortwave_radiation",   # W/m² (solar radiation)
]

SLEEP_SECONDS = 1  # pause between requests to be gentle with the API


def fetch_year(lat: float, lon: float, start: date, end: date) -> pd.DataFrame:
    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
        "hourly": ",".join(HOURLY_VARS),
        "timezone": "GMT",
    }
    for attempt in range(3):
        try:
            r = requests.get(API_URL, params=params, timeout=60)
            r.raise_for_status()
            hourly = r.json()["hourly"]
            df = pd.DataFrame(hourly).rename(columns={"time": "time_utc"})
            return df
        except requests.RequestException as e:
            wait = 5 * (attempt + 1)
            print(f"    error ({e}); retrying in {wait}s")
            time.sleep(wait)
    raise RuntimeError(f"Could not download {start}..{end} for ({lat}, {lon})")


def year_ranges(start: date, end: date):
    current = start
    while current <= end:
        year_end = min(date(current.year, 12, 31), end)
        yield current, year_end
        current = year_end + timedelta(days=1)


def main():
    seed = pd.read_csv(SEED_FILE)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    missing = seed[seed["latitude"].isna() | seed["longitude"].isna()]
    if not missing.empty:
        print("No coordinates (skipped):", ", ".join(missing["betfair_track_name"]))
    seed = seed.dropna(subset=["latitude", "longitude"])

    print(f"Downloading weather {START_DATE} → {END_DATE} for {len(seed)} tracks\n")

    for _, row in seed.iterrows():
        track = row["betfair_track_name"]
        slug = track.lower().replace(" ", "_")
        out_file = OUT_DIR / f"{slug}.csv"

        if out_file.exists():
            print(f"[skip] {track} (already exists)")
            continue

        print(f"[{track}]")
        chunks = []
        for start, end in year_ranges(START_DATE, END_DATE):
            print(f"    {start} → {end}")
            chunks.append(fetch_year(row["latitude"], row["longitude"], start, end))
            time.sleep(SLEEP_SECONDS)

        df = pd.concat(chunks, ignore_index=True)
        df.insert(0, "betfair_track_name", track)
        df.insert(1, "latitude", row["latitude"])
        df.insert(2, "longitude", row["longitude"])
        df.to_csv(out_file, index=False)
        print(f"    -> {len(df):,} rows written to {out_file}")

    print("\nDone.")


if __name__ == "__main__":
    main()

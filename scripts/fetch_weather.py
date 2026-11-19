"""
Descarga el clima horario histórico de Open-Meteo para cada hipódromo del seed.

Uso (desde la raíz del proyecto):
    pip install requests pandas
    python scripts/fetch_weather.py

Salida:
    data/raw/weather/<track>.csv  (un archivo por hipódromo, horas en UTC)

Notas de diseño:
- Pedimos las horas en UTC (timezone=GMT) para evitar ambigüedades con el horario
  de verano. La conversión a hora local se hace en dbt.
- El archivo histórico (ERA5) tiene unos días de demora, por eso END_DATE es
  hoy menos 7 días.
- Se descarga año por año para no pedir rangos demasiado largos en una sola request.
- Si el CSV de un hipódromo ya existe, se saltea (para poder reanudar si se corta).
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
    "apparent_temperature",  # °C (sensación térmica)
    "wind_speed_10m",        # km/h
    "shortwave_radiation",   # W/m² (radiación solar)
]

SLEEP_SECONDS = 1  # pausa entre requests para no saturar la API


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
            print(f"    error ({e}); reintento en {wait}s")
            time.sleep(wait)
    raise RuntimeError(f"No se pudo descargar {start}..{end} para ({lat}, {lon})")


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
        print("Sin coordenadas (se saltean):", ", ".join(missing["betfair_track_name"]))
    seed = seed.dropna(subset=["latitude", "longitude"])

    print(f"Descargando clima {START_DATE} → {END_DATE} para {len(seed)} hipódromos\n")

    for _, row in seed.iterrows():
        track = row["betfair_track_name"]
        slug = track.lower().replace(" ", "_")
        out_file = OUT_DIR / f"{slug}.csv"

        if out_file.exists():
            print(f"[skip] {track} (ya existe)")
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
        print(f"    -> {len(df):,} filas en {out_file}")

    print("\nListo.")


if __name__ == "__main__":
    main()
"""
Genera la plantilla del seed de hipódromos de NSW a partir de todos los CSV de Betfair.

Uso (desde la raíz del proyecto):
    python scripts/build_track_seed_template.py

Salida:
    dbt/seeds/seed_tracks.csv  -> completar latitude / longitude a mano

Si el seed ya existe, NO lo sobrescribe: solo informa si aparecieron hipódromos
nuevos en los datos de Betfair que todavía no están en el seed.
"""
from pathlib import Path

import pandas as pd

RAW_DIR = Path("data/raw/betfair")
OUT_FILE = Path("dbt/seeds/seed_tracks.csv")
STATE = "NSW"

# Formatos de fecha encontrados en los archivos de Betfair:
#   - ISO (YYYY-MM-DD): la mayoría de los archivos
#   - DD/MM/YYYY: ANZ_Thoroughbreds_2025_04.csv (probablemente editado en Excel)
DATE_FORMATS = ["%Y-%m-%d", "%d/%m/%Y"]


def parse_mixed_dates(s: pd.Series) -> pd.Series:
    """Prueba cada formato en orden y se queda con el primero que funcione.
    Misma lógica que coalesce(try_to_date(...), ...) en el modelo de STAGING."""
    result = pd.Series(pd.NaT, index=s.index)
    for fmt in DATE_FORMATS:
        parsed = pd.to_datetime(s, format=fmt, errors="coerce")
        result = result.fillna(parsed)
    return result


files = sorted(RAW_DIR.glob("ANZ_Thoroughbreds_*.csv"))
print(f"Leyendo {len(files)} archivos...")

cols = ["LOCAL_MEETING_DATE", "TRACK", "STATE_CODE", "WIN_MARKET_ID"]
df = pd.concat(
    (pd.read_csv(f, usecols=cols, dtype={"LOCAL_MEETING_DATE": str}) for f in files),
    ignore_index=True,
)

# --- Arreglo de fechas -------------------------------------------------------
df["meeting_date"] = parse_mixed_dates(df["LOCAL_MEETING_DATE"])

unparsed = df[df["meeting_date"].isna()]["LOCAL_MEETING_DATE"].unique()
if len(unparsed) > 0:
    raise ValueError(
        f"{len(unparsed)} fechas con formato desconocido. Ejemplos: {unparsed[:10]}"
    )
print("Todas las fechas se convirtieron correctamente.")
# ----------------------------------------------------------------------------

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

print(f"\n{len(tracks)} hipódromos en {STATE}:\n")
print(tracks.to_string(index=False))

# Plantilla del seed: solo las columnas que van a dbt
seed = tracks[["betfair_track_name"]].copy()
seed["track_name"] = seed["betfair_track_name"]  # nombre "oficial", editable
seed["latitude"] = None
seed["longitude"] = None
seed["timezone"] = "Australia/Sydney"

OUT_FILE.parent.mkdir(parents=True, exist_ok=True)

if OUT_FILE.exists():
    # No pisar el seed curado a mano: solo avisar si aparecieron hipódromos nuevos
    existing = pd.read_csv(OUT_FILE)
    new_tracks = sorted(set(seed["betfair_track_name"]) - set(existing["betfair_track_name"]))
    if new_tracks:
        print(f"\n⚠️  Hipódromos nuevos que no están en {OUT_FILE}: {new_tracks}")
        print("    Agregalos a mano con sus coordenadas.")
    else:
        print(f"\n{OUT_FILE} ya existe y está completo. No se modificó.")
else:
    seed.to_csv(OUT_FILE, index=False)
    print(f"\nPlantilla guardada en {OUT_FILE} -> completar latitude/longitude")
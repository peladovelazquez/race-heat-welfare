"""
NSW Race-Day Heat Dashboard - race-heat-welfare project.

How often are NSW thoroughbred races run in conditions covered by the
Racing NSW Hot Weather Policy, and what drives that exposure?

Runs unchanged in Streamlit in Snowflake (live data) and in Streamlit
Community Cloud / locally (Parquet snapshot). See data_access.py.
"""
import altair as alt
import pandas as pd
import pydeck as pdk
import streamlit as st

from data_access import data_source_label, load_table

st.set_page_config(page_title="NSW Race-Day Heat", layout="wide")

SEASON_ORDER = ["Summer", "Autumn", "Winter", "Spring"]
LEVEL_ORDER = ["None", "Level 1", "Level 2"]
MONTH_LABELS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
REGION_COLOURS = alt.Scale(domain=["Coastal", "Inland"], range=["#1f77b4", "#d62728"])


def show_chart(chart):
    """Full-width Altair chart on both new and older Streamlit versions
    (Streamlit in Snowflake may run an older release than Community Cloud)."""
    try:
        st.altair_chart(chart, width="stretch")
    except TypeError:
        st.altair_chart(chart, use_container_width=True)


# --------------------------------------------------------------------------
# Data
# --------------------------------------------------------------------------
races = load_table("fct_race_conditions")
validation = load_table("fct_heat_event_validation")

races["meeting_date"] = pd.to_datetime(races["meeting_date"])
validation["event_date"] = pd.to_datetime(validation["event_date"])


# --------------------------------------------------------------------------
# Sidebar filters
# --------------------------------------------------------------------------
st.sidebar.header("Filters")

years = sorted(races["meeting_year"].unique().tolist())
year_range = st.sidebar.select_slider(
    "Years", options=years, value=(years[0], years[-1])
)
regions = st.sidebar.multiselect(
    "Region", ["Coastal", "Inland"], default=["Coastal", "Inland"]
)
classes = st.sidebar.multiselect(
    "Racing class",
    ["Metropolitan", "Provincial", "Country"],
    default=["Metropolitan", "Provincial", "Country"],
)
assumption = st.sidebar.radio(
    "WBGT assumption",
    ["Shade (policy definition)", "Sun (worst case)"],
    help=(
        "The Racing NSW policy threshold refers to WBGT in the shade. "
        "The sun estimate is shown as a sensitivity check: it flags far more races."
    ),
)
use_shade = assumption.startswith("Shade")

df = races[
    races["meeting_year"].between(year_range[0], year_range[1])
    & races["region"].isin(regions)
    & races["racing_class"].isin(classes)
].copy()

# Level 1 or above under the selected WBGT assumption
if use_shade:
    df["at_risk"] = df["heat_policy_level_rank"] >= 1
else:
    df["at_risk"] = df["is_level1_temperature"] | df["is_level1_wbgt_sun"]

st.sidebar.caption(data_source_label())


# --------------------------------------------------------------------------
# Header and KPIs
# --------------------------------------------------------------------------
st.title("NSW race-day heat exposure")
st.markdown(
    "How often are NSW thoroughbred races run in conditions covered by the "
    "**Racing NSW Hot Weather Policy**? Betfair race data (2023-2026) joined "
    "with hourly weather (Open-Meteo) for 58 NSW tracks."
)

if df.empty:
    st.warning("No races match the selected filters.")
    st.stop()

summer = df[df["season"] == "Summer"]
confirmed = validation[validation["date_confidence"] == "confirmed"]
confirmed_flagged = (confirmed["model_policy_level"] != "Below thresholds").sum()

k1, k2, k3, k4 = st.columns(4)
k1.metric("Races analysed", f"{len(df):,}")
k2.metric(
    "Summer races at Level 1+",
    f"{summer['at_risk'].mean() * 100:.1f}%" if len(summer) else "n/a",
    help="Share of summer races at or above the Level 1 policy thresholds.",
)
k3.metric(
    "Races at Level 2",
    f"{(df['heat_policy_level'] == 'Level 2').sum():,}",
    help="Max temperature >= 38C or WBGT (shade) >= 28C. Always uses the shade estimate.",
)
k4.metric(
    "Confirmed heat events detected",
    f"{confirmed_flagged} of {len(confirmed)}",
    help="Dated Racing NSW heat measures that our data flags at Level 1 or above.",
)

tab_exposure, tab_drivers, tab_map, tab_fav, tab_valid, tab_explore, tab_method = st.tabs(
    ["Exposure", "Humid vs dry heat", "Map", "Favourites", "Validation",
     "Race explorer", "Methodology"]
)


# --------------------------------------------------------------------------
# Exposure
# --------------------------------------------------------------------------
with tab_exposure:
    st.subheader("Share of races at Level 1 or above, by month")
    monthly = (
        df.groupby(["meeting_month", "region"])
        .agg(n_races=("race_id", "count"), n_at_risk=("at_risk", "sum"))
        .reset_index()
    )
    monthly["pct_at_risk"] = monthly["n_at_risk"] / monthly["n_races"] * 100
    monthly["month"] = monthly["meeting_month"].apply(lambda m: MONTH_LABELS[m - 1])

    chart = (
        alt.Chart(monthly)
        .mark_line(point=True)
        .encode(
            x=alt.X("month:N", sort=MONTH_LABELS, title=None),
            y=alt.Y("pct_at_risk:Q", title="% of races at Level 1+"),
            color=alt.Color("region:N", scale=REGION_COLOURS, title="Region"),
            tooltip=[
                "month", "region", "n_races", "n_at_risk",
                alt.Tooltip("pct_at_risk:Q", format=".1f", title="% at Level 1+"),
            ],
        )
        .properties(height=360)
    )
    show_chart(chart)

    st.subheader("By season and region")
    seasonal = (
        df.groupby(["season", "region"])
        .agg(
            races=("race_id", "count"),
            level1_or_above=("at_risk", "sum"),
            level2=("heat_policy_level", lambda s: (s == "Level 2").sum()),
        )
        .reset_index()
    )
    seasonal["% Level 1+"] = (seasonal["level1_or_above"] / seasonal["races"] * 100).round(1)
    seasonal["season"] = pd.Categorical(seasonal["season"], SEASON_ORDER, ordered=True)
    st.dataframe(seasonal.sort_values(["season", "region"]), hide_index=True)
    if not use_shade:
        st.info(
            "Sun assumption selected: Level 1+ shares are a worst case. "
            "Level 2 counts always use the shade estimate."
        )


# --------------------------------------------------------------------------
# Humid vs dry heat
# --------------------------------------------------------------------------
with tab_drivers:
    st.subheader("What triggers Level 1 in summer?")
    st.markdown(
        "Level 1 is reached when the day's maximum temperature is **35C or more**, "
        "or the WBGT in the shade at the start is **26C or more**. "
        "On the coast, humidity (WBGT) drives most of the exposure; inland, "
        "it is extreme dry heat (temperature)."
    )
    drivers = summer.copy()
    drivers["driver"] = None
    drivers.loc[summer["is_level1_temperature"] & ~summer["is_level1_wbgt"], "driver"] = "Temperature only"
    drivers.loc[~summer["is_level1_temperature"] & summer["is_level1_wbgt"], "driver"] = "WBGT (humidity) only"
    drivers.loc[summer["is_level1_temperature"] & summer["is_level1_wbgt"], "driver"] = "Both"
    drivers = drivers.dropna(subset=["driver"])

    if drivers.empty:
        st.info("No summer races at Level 1 or above for the selected filters.")
    else:
        driver_counts = drivers.groupby(["region", "driver"]).size().reset_index(name="races")
        chart = (
            alt.Chart(driver_counts)
            .mark_bar()
            .encode(
                y=alt.Y("region:N", title=None),
                x=alt.X("races:Q", title="Summer races at Level 1+"),
                color=alt.Color(
                    "driver:N",
                    title="Triggered by",
                    sort=["Temperature only", "Both", "WBGT (humidity) only"],
                ),
                tooltip=["region", "driver", "races"],
            )
            .properties(height=200)
        )
        show_chart(chart)
        st.caption("Uses the shade WBGT estimate (policy definition).")


# --------------------------------------------------------------------------
# Map
# --------------------------------------------------------------------------
with tab_map:
    st.subheader("Summer exposure by track")
    tracks = (
        summer.groupby(["betfair_track_name", "track_name", "region", "latitude", "longitude"])
        .agg(n_races=("race_id", "count"), n_at_risk=("at_risk", "sum"))
        .reset_index()
    )
    if tracks.empty:
        st.info("No summer races for the selected filters.")
    else:
        tracks["pct_at_risk"] = tracks["n_at_risk"] / tracks["n_races"] * 100
        max_pct = max(tracks["pct_at_risk"].max(), 1)
        tracks["red"] = (tracks["pct_at_risk"] / max_pct * 255).round().astype(int)
        tracks["green"] = 200 - (tracks["pct_at_risk"] / max_pct * 170).round().astype(int)
        tracks["radius"] = 2500 + tracks["n_races"] * 40
        tracks["label"] = tracks["pct_at_risk"].map(lambda p: f"{p:.1f}%")

        layer = pdk.Layer(
            "ScatterplotLayer",
            data=tracks,
            get_position="[longitude, latitude]",
            get_radius="radius",
            get_fill_color="[red, green, 60, 180]",
            pickable=True,
        )
        view = pdk.ViewState(latitude=-32.5, longitude=148.5, zoom=5.2)
        st.pydeck_chart(
            pdk.Deck(
                layers=[layer],
                initial_view_state=view,
                tooltip={"text": "{track_name}\n{n_races} summer races\n{label} at Level 1+"},
            )
        )
        st.caption("Circle size = number of summer races; colour = share at Level 1 or above.")


# --------------------------------------------------------------------------
# Favourites
# --------------------------------------------------------------------------
with tab_fav:
    st.subheader("Do favourites win less often than the market expects in the heat?")
    fav = df[df["favourite_win_bsp"].notna() & ~df["has_joint_favourites"].astype(bool)]
    fav_summary = (
        fav.groupby(["heat_policy_level", "heat_policy_level_rank"])
        .agg(
            n_races=("race_id", "count"),
            actual=("favourite_won", "mean"),
            expected=("favourite_implied_probability", "mean"),
        )
        .reset_index()
        .sort_values("heat_policy_level_rank")
    )
    fav_summary["actual_pct"] = fav_summary["actual"] * 100
    fav_summary["expected_pct"] = fav_summary["expected"] * 100
    fav_summary["margin"] = (
        1.96 * (fav_summary["actual"] * (1 - fav_summary["actual"]) / fav_summary["n_races"]) ** 0.5 * 100
    )
    fav_summary["lower"] = fav_summary["actual_pct"] - fav_summary["margin"]
    fav_summary["upper"] = fav_summary["actual_pct"] + fav_summary["margin"]

    base = alt.Chart(fav_summary).encode(
        x=alt.X("heat_policy_level:N", sort=LEVEL_ORDER, title="Heat policy level")
    )
    bars = base.mark_bar(opacity=0.7).encode(
        y=alt.Y("actual_pct:Q", title="Favourite win rate (%)"),
        tooltip=[
            "heat_policy_level", "n_races",
            alt.Tooltip("actual_pct:Q", format=".1f", title="Actual %"),
            alt.Tooltip("expected_pct:Q", format=".1f", title="Expected %"),
            alt.Tooltip("margin:Q", format=".1f", title="95% margin (pp)"),
        ],
    )
    error = base.mark_rule(color="black").encode(y="lower:Q", y2="upper:Q")
    expected = base.mark_tick(color="orange", thickness=3, size=40).encode(y="expected_pct:Q")
    show_chart((bars + error + expected).properties(height=360))
    st.markdown(
        "Bars = actual favourite win rate, black lines = 95% margin of error, "
        "orange ticks = market expectation (average of 1 / BSP). "
        "In normal conditions favourites beat the market expectation (the well-known "
        "favourite-longshot bias). On Level 1 and Level 2 days that edge disappears, "
        "but the margins of error are too wide to call it a real effect."
    )


# --------------------------------------------------------------------------
# Validation
# --------------------------------------------------------------------------
with tab_valid:
    st.subheader("Case-study validation against Racing NSW announcements")
    st.markdown(
        "Dated public announcements of heat measures (policy invoked, meetings "
        "postponed, transferred or with changed race times), compared with what "
        "our weather data says for that track and day. The list is **not complete** "
        "(Racing NSW news items rarely state the year), so this is a case study, "
        "not a detection rate."
    )
    cols = [
        "event_date", "betfair_track_name", "action", "date_confidence",
        "forecast_max_temperature_c", "day_max_temperature_c",
        "day_max_wbgt_shade_c", "model_policy_level", "meeting_in_betfair",
        "first_race_hour",
    ]
    st.dataframe(
        validation[cols].sort_values("event_date"),
        hide_index=True,
        column_config={"event_date": st.column_config.DateColumn("event_date")},
    )


# --------------------------------------------------------------------------
# Race explorer
# --------------------------------------------------------------------------
with tab_explore:
    st.subheader("Race explorer")
    c1, c2 = st.columns(2)
    track_options = sorted(df["track_name"].dropna().unique().tolist())
    selected_tracks = c1.multiselect("Tracks", track_options)
    selected_levels = c2.multiselect("Heat policy level", LEVEL_ORDER, default=["Level 1", "Level 2"])

    explore = df.copy()
    if selected_tracks:
        explore = explore[explore["track_name"].isin(selected_tracks)]
    if selected_levels:
        explore = explore[explore["heat_policy_level"].isin(selected_levels)]

    explore_cols = [
        "meeting_date", "track_name", "race_number", "start_time_band",
        "temperature_c", "relative_humidity_pct", "wbgt_shade_estimated_c",
        "day_max_temperature_c", "heat_policy_level", "n_runners",
        "favourite_horse_name", "favourite_won",
    ]
    explore = explore.sort_values("meeting_date", ascending=False)[explore_cols]
    st.caption(f"{len(explore):,} races")
    st.dataframe(explore, hide_index=True)
    st.download_button(
        "Download CSV",
        explore.to_csv(index=False).encode("utf-8"),
        file_name="race_heat_explorer.csv",
        mime="text/csv",
    )


# --------------------------------------------------------------------------
# Methodology
# --------------------------------------------------------------------------
with tab_method:
    st.subheader("Methodology and limitations")
    st.markdown(
        """
**Data**
- Races: Betfair Data Scientists historical ANZ thoroughbred files (2023 to Oct 2026), NSW only.
- Weather: Open-Meteo historical hourly data (ERA5 reanalysis) at each track's coordinates.
- Pipeline: Python ingestion, Snowflake (infrastructure as code with DCM Projects), dbt transformations and tests.

**Heat policy levels** (Racing NSW "Racing in Hot Weather" policy)
- Level 1: day's maximum temperature >= 35C, or WBGT in the shade at the start >= 26C.
- Level 2: day's maximum temperature >= 38C, or WBGT in the shade at the start >= 28C.

**Estimated WBGT**
- Shade WBGT = 0.7 x wet-bulb temperature (Stull 2011) + 0.3 x air temperature. Used for the policy levels.
- Sun WBGT (Bureau of Meteorology approximation) is shown only as a worst case.
- Both ignore on-course conditions (shade, wind, surface); inputs are gridded reanalysis data. Treat them as indicators, not readings.

**Key limitations**
- The result is very sensitive to the shade vs sun assumption (about 9% vs 50%+ of summer races at Level 1+).
- Race times are in Sydney time (inferred from the data and confirmed against a Racing NSW race-day preview).
- The heat-event list used for validation is incomplete; 4 candidate events with inferred dates failed verification and were discarded.
- Favourite analysis: too few Level 1/2 races to detect small effects.
"""
    )

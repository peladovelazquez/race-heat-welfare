-- =============================================================================
-- load_raw.sql
-- Uploads the local CSV files to the stages and loads them into the RAW tables.
-- This is an OPERATION (moving data), not state: that's why it is not in DCM.
--
-- From the project root:
--
--   snow sql -c racing_dev -f snowflake/load/load_raw.sql \
--       -D "env=DEV" -D "project_dir=$(pwd)"
--
-- COPY INTO keeps track of the files it has already loaded (64 days): running
-- it twice skips already-loaded files, so no data is duplicated.
-- =============================================================================

USE ROLE RACING_<% env %>_ENGINEER;
USE DATABASE RACING_<% env %>;
USE WAREHOUSE RACING_WH_<% env %>;

-- 1. Upload files to the stages (PUT gzips them automatically) -----------------
PUT 'file://<% project_dir %>/data/raw/betfair/*.csv' @RACING_<% env %>.RAW.STG_BETFAIR AUTO_COMPRESS = TRUE;
PUT 'file://<% project_dir %>/data/raw/weather/*.csv' @RACING_<% env %>.RAW.STG_WEATHER AUTO_COMPRESS = TRUE;


-- 2. Betfair ------------------------------------------------------------------
COPY INTO RACING_<% env %>.RAW.BETFAIR_RUNNERS (
    LOCAL_MEETING_DATE,
    SCHEDULED_RACE_TIME,
    ACTUAL_OFF_TIME,
    TRACK,
    STATE_CODE,
    RACE_NO,
    WIN_MARKET_ID,
    WIN_MARKET_NAME,
    PLACE_MARKET_ID,
    RACING_TYPE,
    DISTANCE,
    RACE_TYPE,
    SELECTION_ID,
    TAB_NUMBER,
    SELECTION_NAME,
    WIN_RESULT,
    WIN_BSP,
    PLACE_RESULT,
    PLACE_BSP,
    WIN_BSP_VOLUME,
    WIN_PREPLAY_MAX_PRICE_TAKEN,
    WIN_PREPLAY_MIN_PRICE_TAKEN,
    WIN_PREPLAY_LAST_PRICE_TAKEN,
    WIN_PREPLAY_WEIGHTED_AVERAGE_PRICE_TAKEN,
    WIN_PREPLAY_VOLUME,
    WIN_INPLAY_MAX_PRICE_TAKEN,
    WIN_INPLAY_MIN_PRICE_TAKEN,
    WIN_LAST_PRICE_TAKEN,
    WIN_INPLAY_WEIGHTED_AVERAGE_PRICE_TAKEN,
    WIN_INPLAY_VOLUME,
    PLACE_BSP_VOLUME,
    PLACE_MAX_PRICE_TAKEN,
    PLACE_MIN_PRICE_TAKEN,
    PLACE_LAST_PRICE_TAKEN,
    PLACE_WEIGHTED_AVERAGE_PRICE_TAKEN,
    PLACE_PREPLAY_VOLUME,
    BEST_AVAIL_BACK_AT_SCHEDULED_OFF,
    BEST_AVAIL_LAY_AT_SCHEDULED_OFF,
    BACK_MARKET_PERCENTAGE_AT_SCHEDULED_OFF,
    LAY_MARKET_PERCENTAGE_AT_SCHEDULED_OFF,
    _SOURCE_FILE,
    _SOURCE_ROW,
    _LOADED_AT
)
FROM (
    SELECT
        $1,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8,
        $9,
        $10,
        $11,
        $12,
        $13,
        $14,
        $15,
        $16,
        $17,
        $18,
        $19,
        $20,
        $21,
        $22,
        $23,
        $24,
        $25,
        $26,
        $27,
        $28,
        $29,
        $30,
        $31,
        $32,
        $33,
        $34,
        $35,
        $36,
        $37,
        $38,
        $39,
        $40,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP()
    FROM @RACING_<% env %>.RAW.STG_BETFAIR
)
PATTERN = '.*ANZ_Thoroughbreds_.*[.]csv[.]gz'
FILE_FORMAT = (FORMAT_NAME = 'RACING_<% env %>.RAW.FF_CSV');


-- 3. Weather ------------------------------------------------------------------
COPY INTO RACING_<% env %>.RAW.WEATHER_HOURLY (
    BETFAIR_TRACK_NAME,
    LATITUDE,
    LONGITUDE,
    TIME_UTC,
    TEMPERATURE_2M,
    RELATIVE_HUMIDITY_2M,
    DEW_POINT_2M,
    APPARENT_TEMPERATURE,
    WIND_SPEED_10M,
    SHORTWAVE_RADIATION,
    _SOURCE_FILE,
    _SOURCE_ROW,
    _LOADED_AT
)
FROM (
    SELECT
        $1,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8,
        $9,
        $10,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP()
    FROM @RACING_<% env %>.RAW.STG_WEATHER
)
PATTERN = '.*[.]csv[.]gz'
FILE_FORMAT = (FORMAT_NAME = 'RACING_<% env %>.RAW.FF_CSV');


-- 4. Check --------------------------------------------------------------------
SELECT
    'BETFAIR_RUNNERS'             AS table_name,
    COUNT(DISTINCT _SOURCE_FILE)  AS n_files,   -- expected: 46
    COUNT(*)                      AS n_rows
FROM RACING_<% env %>.RAW.BETFAIR_RUNNERS
UNION ALL
SELECT
    'WEATHER_HOURLY',
    COUNT(DISTINCT _SOURCE_FILE),               -- expected: 57
    COUNT(*)
FROM RACING_<% env %>.RAW.WEATHER_HOURLY;

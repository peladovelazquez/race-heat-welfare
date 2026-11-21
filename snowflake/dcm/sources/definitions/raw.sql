-- =============================================================================
-- RAW layer: file format, internal stages and landing tables.
--
-- Principle: everything in RAW is VARCHAR, exactly as it arrives in the file.
-- Data types and mixed formats (dates, times) are resolved in STAGING with dbt,
-- so loads never fail on an unexpected format and no information is lost.
--
-- DCM note: columns of an existing table cannot be reordered. New columns are
-- always appended at the end.
-- =============================================================================

DEFINE FILE FORMAT RACING_{{env}}.RAW.FF_CSV
    TYPE                           = CSV
    SKIP_HEADER                    = 1
    FIELD_OPTIONALLY_ENCLOSED_BY   = '"'
    EMPTY_FIELD_AS_NULL            = TRUE
    NULL_IF                        = ('', 'NULL', 'null')
    TRIM_SPACE                     = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = TRUE
    COMMENT = 'CSV with header. Fails if the number of columns changes.';

-- Internal stages (phase 1). To be replaced later by an external S3 stage.
DEFINE STAGE RACING_{{env}}.RAW.STG_BETFAIR
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Betfair monthly files (ANZ Thoroughbreds)';

DEFINE STAGE RACING_{{env}}.RAW.STG_WEATHER
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Open-Meteo hourly weather, one file per track';

-- Landing tables
DEFINE TABLE RACING_{{env}}.RAW.BETFAIR_RUNNERS (
    LOCAL_MEETING_DATE                       VARCHAR,
    SCHEDULED_RACE_TIME                      VARCHAR,
    ACTUAL_OFF_TIME                          VARCHAR,
    TRACK                                    VARCHAR,
    STATE_CODE                               VARCHAR,
    RACE_NO                                  VARCHAR,
    WIN_MARKET_ID                            VARCHAR,
    WIN_MARKET_NAME                          VARCHAR,
    PLACE_MARKET_ID                          VARCHAR,
    RACING_TYPE                              VARCHAR,
    DISTANCE                                 VARCHAR,
    RACE_TYPE                                VARCHAR,
    SELECTION_ID                             VARCHAR,
    TAB_NUMBER                               VARCHAR,
    SELECTION_NAME                           VARCHAR,
    WIN_RESULT                               VARCHAR,
    WIN_BSP                                  VARCHAR,
    PLACE_RESULT                             VARCHAR,
    PLACE_BSP                                VARCHAR,
    WIN_BSP_VOLUME                           VARCHAR,
    WIN_PREPLAY_MAX_PRICE_TAKEN              VARCHAR,
    WIN_PREPLAY_MIN_PRICE_TAKEN              VARCHAR,
    WIN_PREPLAY_LAST_PRICE_TAKEN             VARCHAR,
    WIN_PREPLAY_WEIGHTED_AVERAGE_PRICE_TAKEN VARCHAR,
    WIN_PREPLAY_VOLUME                       VARCHAR,
    WIN_INPLAY_MAX_PRICE_TAKEN               VARCHAR,
    WIN_INPLAY_MIN_PRICE_TAKEN               VARCHAR,
    WIN_LAST_PRICE_TAKEN                     VARCHAR,
    WIN_INPLAY_WEIGHTED_AVERAGE_PRICE_TAKEN  VARCHAR,
    WIN_INPLAY_VOLUME                        VARCHAR,
    PLACE_BSP_VOLUME                         VARCHAR,
    PLACE_MAX_PRICE_TAKEN                    VARCHAR,
    PLACE_MIN_PRICE_TAKEN                    VARCHAR,
    PLACE_LAST_PRICE_TAKEN                   VARCHAR,
    PLACE_WEIGHTED_AVERAGE_PRICE_TAKEN       VARCHAR,
    PLACE_PREPLAY_VOLUME                     VARCHAR,
    BEST_AVAIL_BACK_AT_SCHEDULED_OFF         VARCHAR,
    BEST_AVAIL_LAY_AT_SCHEDULED_OFF          VARCHAR,
    BACK_MARKET_PERCENTAGE_AT_SCHEDULED_OFF  VARCHAR,
    LAY_MARKET_PERCENTAGE_AT_SCHEDULED_OFF   VARCHAR,
    _SOURCE_FILE                             VARCHAR COMMENT 'Source file in the stage',
    _SOURCE_ROW                              NUMBER COMMENT 'Row number within the source file',
    _LOADED_AT                               TIMESTAMP_LTZ COMMENT 'Load timestamp'
)
COMMENT = 'One row per runner per race, as provided by Betfair';

DEFINE TABLE RACING_{{env}}.RAW.WEATHER_HOURLY (
    BETFAIR_TRACK_NAME   VARCHAR,
    LATITUDE             VARCHAR,
    LONGITUDE            VARCHAR,
    TIME_UTC             VARCHAR,
    TEMPERATURE_2M       VARCHAR,
    RELATIVE_HUMIDITY_2M VARCHAR,
    DEW_POINT_2M         VARCHAR,
    APPARENT_TEMPERATURE VARCHAR,
    WIND_SPEED_10M       VARCHAR,
    SHORTWAVE_RADIATION  VARCHAR,
    _SOURCE_FILE         VARCHAR COMMENT 'Source file in the stage',
    _SOURCE_ROW          NUMBER COMMENT 'Row number within the source file',
    _LOADED_AT           TIMESTAMP_LTZ COMMENT 'Load timestamp'
)
COMMENT = 'Hourly weather per track (UTC), as provided by Open-Meteo';

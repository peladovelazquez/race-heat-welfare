/*
    Hourly weather per track, typed, with the observation time in both UTC
    and Sydney local time (NSW: AEST/AEDT, daylight saving handled by
    CONVERT_TIMEZONE).
*/

with source as (

    select * from {{ source('open_meteo', 'weather_hourly') }}

),

typed as (

    select
        betfair_track_name,
        try_to_double(latitude)                                     as latitude,
        try_to_double(longitude)                                    as longitude,
        try_to_timestamp_ntz(time_utc, 'YYYY-MM-DD"T"HH24:MI')      as observed_at_utc,

        try_to_double(temperature_2m)                               as temperature_c,
        try_to_double(relative_humidity_2m)                         as relative_humidity_pct,
        try_to_double(dew_point_2m)                                 as dew_point_c,
        try_to_double(apparent_temperature)                         as apparent_temperature_c,
        try_to_double(wind_speed_10m)                               as wind_speed_kmh,
        try_to_double(shortwave_radiation)                          as shortwave_radiation_wm2,

        _source_file,
        _source_row,
        _loaded_at

    from source

)

select
    betfair_track_name || '|' || to_char(observed_at_utc, 'YYYY-MM-DD HH24:MI')    as weather_hour_id,
    betfair_track_name,
    latitude,
    longitude,
    observed_at_utc,
    convert_timezone('UTC', 'Australia/Sydney', observed_at_utc)                    as observed_at_sydney,
    temperature_c,
    relative_humidity_pct,
    dew_point_c,
    apparent_temperature_c,
    wind_speed_kmh,
    shortwave_radiation_wm2,
    _source_file,
    _source_row,
    _loaded_at
from typed

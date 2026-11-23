/*
    NSW races enriched with the weather at the race's start time and the
    track's conditions for the whole meeting day.

    - Race weather: the hourly observation nearest to the scheduled start
      (start time rounded to the nearest hour, in UTC).
    - Meeting-day weather: maximum temperature and WBGT at the track over the
      local (Sydney) calendar day, comparable to the forecast maximum that
      Racing NSW uses to invoke its Hot Weather Policy.
*/

with races as (

    select
        *,
        -- nearest hourly observation to the scheduled start
        date_trunc('hour', dateadd('minute', 30, scheduled_start_utc)) as weather_hour_utc
    from {{ ref('int_races') }}
    where state_code = 'NSW'

),

weather as (

    select
        *,
        {{ estimate_wbgt('temperature_c', 'relative_humidity_pct') }} as wbgt_estimated_c
    from {{ ref('stg_open_meteo__weather_hourly') }}

),

meeting_day_weather as (

    select
        betfair_track_name,
        observed_at_sydney::date        as local_date,
        max(temperature_c)              as day_max_temperature_c,
        max(wbgt_estimated_c)           as day_max_wbgt_estimated_c
    from weather
    group by betfair_track_name, local_date

),

final as (

    select
        races.*,

        -- weather at race start
        weather.temperature_c,
        weather.relative_humidity_pct,
        weather.dew_point_c,
        weather.apparent_temperature_c,
        weather.wind_speed_kmh,
        weather.shortwave_radiation_wm2,
        weather.wbgt_estimated_c,

        -- meeting day
        meeting_day_weather.day_max_temperature_c,
        meeting_day_weather.day_max_wbgt_estimated_c

    from races
    left join weather
        on  races.betfair_track_name = weather.betfair_track_name
        and races.weather_hour_utc = weather.observed_at_utc
    left join meeting_day_weather
        on  races.betfair_track_name = meeting_day_weather.betfair_track_name
        and races.meeting_date = meeting_day_weather.local_date

)

select * from final

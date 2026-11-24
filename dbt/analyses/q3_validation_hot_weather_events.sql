/*
    Q3 - Case-study validation: does our weather data flag the days on which
    Racing NSW took heat measures?

    For each hand-collected event (seed_hot_weather_events) it shows:
      - the track's maximum temperature and maximum WBGT (shade) that day,
        from our weather data (available even if the meeting did not run);
      - the policy level our data implies (Level 1 / Level 2 thresholds);
      - whether a meeting appears in Betfair that day. For 'probable' dates,
        a missing meeting suggests the inferred year is wrong (unless the
        meeting was postponed or transferred).

    Limitation: announcements are based on FORECAST maximums, while our values
    are hourly reanalysis data (Open-Meteo / ERA5), so small differences are
    expected. The event list is incomplete, so this is not a recall metric.
*/

with events as (

    select * from {{ ref('seed_hot_weather_events') }}

),

daily_weather as (

    select
        betfair_track_name,
        observed_at_sydney::date                                                    as local_date,
        max(temperature_c)                                                          as day_max_temperature_c,
        max({{ estimate_wbgt_shade('temperature_c', 'relative_humidity_pct') }})    as day_max_wbgt_shade_c
    from {{ ref('stg_open_meteo__weather_hourly') }}
    group by betfair_track_name, local_date

),

meetings as (

    select
        betfair_track_name,
        meeting_date,
        count(*)                as n_races,
        min(start_hour_local)   as first_race_hour
    from {{ ref('fct_race_conditions') }}
    group by betfair_track_name, meeting_date

)

select
    events.event_date,
    events.betfair_track_name,
    events.action,
    events.date_confidence,
    events.forecast_max_temperature_c,
    daily_weather.day_max_temperature_c,
    daily_weather.day_max_wbgt_shade_c,
    case
        when daily_weather.day_max_temperature_c >= {{ var('heat_policy_level2_temperature_c') }}
          or daily_weather.day_max_wbgt_shade_c  >= {{ var('heat_policy_level2_wbgt_c') }}
            then 'Level 2'
        when daily_weather.day_max_temperature_c >= {{ var('heat_policy_max_temperature_c') }}
          or daily_weather.day_max_wbgt_shade_c  >= {{ var('heat_policy_wbgt_c') }}
            then 'Level 1'
        else 'Below thresholds'
    end                                         as model_policy_level,
    meetings.n_races is not null                as meeting_in_betfair,
    meetings.n_races,
    meetings.first_race_hour
from events
left join daily_weather
    on  events.betfair_track_name = daily_weather.betfair_track_name
    and events.event_date = daily_weather.local_date
left join meetings
    on  events.betfair_track_name = meetings.betfair_track_name
    and events.event_date = meetings.meeting_date
order by events.event_date, events.betfair_track_name

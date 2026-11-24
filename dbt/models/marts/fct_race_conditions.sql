/*
    One row per NSW race with its heat conditions and heat-risk level, ready
    for analysis and the dashboard.

    heat_policy_level mirrors the two levels of the Racing NSW "Racing in Hot
    Weather" policy (thresholds are dbt vars, see dbt_project.yml):
      - Level 2: meeting-day max temperature >= 38C or WBGT (shade) at start >= 28C
      - Level 1: meeting-day max temperature >= 35C or WBGT (shade) at start >= 26C
      - None:    below both Level 1 thresholds
    Validated against dated public announcements (dbt/analyses/
    q3_validation_hot_weather_events.sql).

    is_level1_wbgt_sun applies the Level 1 WBGT threshold to the sun estimate
    (worst case) and is kept for sensitivity analysis only.
*/

with races as (

    select * from {{ ref('int_races__weather') }}

),

tracks as (

    select * from {{ ref('seed_tracks') }}

),

enriched as (

    select
        races.*,
        tracks.track_name,
        tracks.region,
        tracks.racing_class,

        -- calendar (southern hemisphere seasons)
        year(races.meeting_date)                        as meeting_year,
        month(races.meeting_date)                       as meeting_month,
        case
            when month(races.meeting_date) in (12, 1, 2)  then 'Summer'
            when month(races.meeting_date) in (3, 4, 5)   then 'Autumn'
            when month(races.meeting_date) in (6, 7, 8)   then 'Winter'
            else 'Spring'
        end                                             as season,
        dayname(races.meeting_date)                     as day_of_week,
        dayofweekiso(races.meeting_date) in (6, 7)      as is_weekend,

        -- start time (local)
        hour(races.scheduled_start_sydney)              as start_hour_local,
        case
            when hour(races.scheduled_start_sydney) < 13 then 'Before 1pm'
            when hour(races.scheduled_start_sydney) < 16 then '1pm to 4pm'
            else '4pm or later'
        end                                             as start_time_band,

        -- policy thresholds
        races.day_max_temperature_c  >= {{ var('heat_policy_max_temperature_c') }}     as is_level1_temperature,
        races.wbgt_shade_estimated_c >= {{ var('heat_policy_wbgt_c') }}                as is_level1_wbgt,
        races.day_max_temperature_c  >= {{ var('heat_policy_level2_temperature_c') }}  as is_level2_temperature,
        races.wbgt_shade_estimated_c >= {{ var('heat_policy_level2_wbgt_c') }}         as is_level2_wbgt,
        races.wbgt_sun_estimated_c   >= {{ var('heat_policy_wbgt_c') }}                as is_level1_wbgt_sun

    from races
    left join tracks
        on races.betfair_track_name = tracks.betfair_track_name

),

final as (

    select
        -- race
        race_id,
        meeting_date,
        betfair_track_name,
        track_name,
        region,
        racing_class,
        race_number,
        race_name,
        race_type,
        distance_m,

        -- calendar and time
        meeting_year,
        meeting_month,
        season,
        day_of_week,
        is_weekend,
        scheduled_start_sydney,
        scheduled_start_utc,
        start_hour_local,
        start_time_band,

        -- weather at start
        temperature_c,
        relative_humidity_pct,
        apparent_temperature_c,
        wind_speed_kmh,
        shortwave_radiation_wm2,
        wet_bulb_c,
        wbgt_shade_estimated_c,
        wbgt_sun_estimated_c,

        -- meeting day
        day_max_temperature_c,
        day_max_wbgt_shade_estimated_c,
        day_max_wbgt_sun_estimated_c,

        -- heat policy level
        is_level1_temperature,
        is_level1_wbgt,
        is_level2_temperature,
        is_level2_wbgt,
        is_level1_wbgt_sun,
        case
            when is_level2_temperature or is_level2_wbgt then 'Level 2'
            when is_level1_temperature or is_level1_wbgt then 'Level 1'
            else 'None'
        end                                             as heat_policy_level,
        case
            when is_level2_temperature or is_level2_wbgt then 2
            when is_level1_temperature or is_level1_wbgt then 1
            else 0
        end                                             as heat_policy_level_rank,

        -- field and result
        n_runners,
        n_missing_tab_numbers,
        is_dead_heat,

        -- favourite
        favourite_horse_name,
        favourite_win_bsp,
        favourite_implied_probability,
        favourite_won,
        has_joint_favourites

    from enriched

)

select * from final

/*
    One row per NSW race with its heat conditions and heat-risk level, ready
    for analysis and the dashboard.

    Heat risk follows the Racing NSW "Racing in Hot Weather" policy thresholds
    (dbt vars, see dbt_project.yml):
      - meeting-day maximum temperature   >= heat_policy_max_temperature_c
      - estimated WBGT in the SHADE at start >= heat_policy_wbgt_c
    'High' when both are met, 'Elevated' when one is met, 'None' otherwise.

    is_above_wbgt_sun_threshold applies the same threshold to the sun estimate
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
        races.day_max_temperature_c >= {{ var('heat_policy_max_temperature_c') }}
                                                        as is_above_temperature_threshold,
        races.wbgt_shade_estimated_c >= {{ var('heat_policy_wbgt_c') }}
                                                        as is_above_wbgt_threshold,
        races.wbgt_sun_estimated_c >= {{ var('heat_policy_wbgt_c') }}
                                                        as is_above_wbgt_sun_threshold

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

        -- heat risk
        is_above_temperature_threshold,
        is_above_wbgt_threshold,
        is_above_wbgt_sun_threshold,
        case
            when is_above_temperature_threshold and is_above_wbgt_threshold then 'High'
            when is_above_temperature_threshold or  is_above_wbgt_threshold then 'Elevated'
            else 'None'
        end                                             as heat_risk_level,

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

/*
    One row per race (all states).

    - Start times: Betfair race times are in Sydney time (AEST/AEDT) for every
      state, as inferred from the data (see snowflake/analysis/
      check_betfair_time_zone.sql). They are converted to UTC to join weather.
      Caveat: for late-night races outside NSW (e.g. WA night meetings) the
      Sydney time can fall on the next calendar day; this does not affect NSW.
    - Favourite: the runner with the lowest Betfair Starting Price (BSP).
      Ties are broken by TAB number and flagged with has_joint_favourites.
    - Dead heats: races with more than one winner (legitimate, ~0.17%).
*/

with runners as (

    select * from {{ ref('stg_betfair__runners') }}

),

races as (

    select
        race_id,
        any_value(meeting_date)             as meeting_date,
        any_value(scheduled_time)           as scheduled_time,
        any_value(actual_off_time)          as actual_off_time,
        any_value(betfair_track_name)       as betfair_track_name,
        any_value(state_code)               as state_code,
        any_value(race_number)              as race_number,
        any_value(race_name)                as race_name,
        any_value(racing_type)              as racing_type,
        any_value(race_type)                as race_type,
        any_value(distance_m)               as distance_m,

        count(*)                            as n_runners,
        count_if(is_winner)                 as n_winners,
        max(tab_number)                     as max_tab_number,
        min(win_bsp)                        as min_win_bsp,
        count_if(win_bsp is not null)       as n_runners_with_bsp

    from runners
    group by race_id

),

joint_favourites as (

    select
        runners.race_id,
        count(*) as n_runners_at_min_bsp
    from runners
    inner join races
        on  runners.race_id = races.race_id
        and runners.win_bsp = races.min_win_bsp
    group by runners.race_id

),

favourites as (

    select
        race_id,
        selection_id        as favourite_selection_id,
        horse_name          as favourite_horse_name,
        win_bsp             as favourite_win_bsp,
        is_winner           as favourite_won
    from runners
    where win_bsp is not null
    qualify row_number() over (
        partition by race_id
        order by win_bsp asc, tab_number asc
    ) = 1

),

final as (

    select
        races.race_id,
        races.meeting_date,
        races.betfair_track_name,
        races.state_code,
        races.race_number,
        races.race_name,
        races.racing_type,
        races.race_type,
        races.distance_m,

        -- start times
        timestamp_ntz_from_parts(races.meeting_date, races.scheduled_time)  as scheduled_start_sydney,
        convert_timezone(
            'Australia/Sydney', 'UTC', scheduled_start_sydney
        )                                                                   as scheduled_start_utc,
        timestamp_ntz_from_parts(races.meeting_date, races.actual_off_time) as actual_off_sydney,

        -- field
        races.n_runners,
        races.max_tab_number,
        races.max_tab_number - races.n_runners      as n_missing_tab_numbers,

        -- result
        races.n_winners,
        races.n_winners > 1                         as is_dead_heat,

        -- favourite
        favourites.favourite_selection_id,
        favourites.favourite_horse_name,
        favourites.favourite_win_bsp,
        round(1 / favourites.favourite_win_bsp, 4)  as favourite_implied_probability,
        favourites.favourite_won,
        coalesce(joint_favourites.n_runners_at_min_bsp, 0) > 1
                                                    as has_joint_favourites,
        races.n_runners_with_bsp

    from races
    left join favourites
        on races.race_id = favourites.race_id
    left join joint_favourites
        on races.race_id = joint_favourites.race_id

)

select * from final

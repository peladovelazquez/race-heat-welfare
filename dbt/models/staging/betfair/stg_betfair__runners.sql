/*
    One row per runner per race.

    - Parses the three date/time formats found in the source files:
        * ISO dates and 24h times with milliseconds (most files)
        * 24h times without milliseconds (2025-01 to 2025-07)
        * DD/MM/YYYY dates and 12h AM/PM times (2025-04, likely edited in Excel)
    - Removes duplicated rows (found in at least one race).
    - Keeps only the columns relevant to the analysis.

    NOTE: the time zone of the race times is still to be confirmed, so they
    are kept as timezone-naive values here.
*/

with source as (

    select * from {{ source('betfair', 'betfair_runners') }}

),

renamed as (

    select
        -- identifiers
        win_market_id || '-' || selection_id                    as runner_id,
        win_market_id                                           as race_id,
        selection_id,

        -- race
        coalesce(
            try_to_date(local_meeting_date, 'YYYY-MM-DD'),
            try_to_date(local_meeting_date, 'DD/MM/YYYY')
        )                                                       as meeting_date,
        coalesce(
            try_to_time(scheduled_race_time, 'HH24:MI:SS.FF3'),
            try_to_time(scheduled_race_time, 'HH24:MI:SS'),
            try_to_time(scheduled_race_time, 'HH12:MI:SS AM')
        )                                                       as scheduled_time,
        coalesce(
            try_to_time(actual_off_time, 'HH24:MI:SS.FF3'),
            try_to_time(actual_off_time, 'HH24:MI:SS'),
            try_to_time(actual_off_time, 'HH12:MI:SS AM')
        )                                                       as actual_off_time,
        track                                                   as betfair_track_name,
        state_code,
        try_to_number(race_no)                                  as race_number,
        win_market_name                                         as race_name,
        racing_type,
        race_type,
        try_to_number(distance)                                 as distance_m,

        -- runner
        selection_name                                          as horse_name,
        try_to_number(tab_number)                               as tab_number,
        win_result,
        place_result,
        win_result = 'WINNER'                                   as is_winner,
        place_result = 'WINNER'                                 as is_placed,

        -- market (Betfair Starting Price)
        try_to_double(win_bsp)                                  as win_bsp,
        try_to_double(place_bsp)                                as place_bsp,
        try_to_double(win_bsp_volume)                           as win_bsp_volume,

        -- audit
        _source_file,
        _source_row,
        _loaded_at

    from source

),

deduplicated as (

    select *
    from renamed
    qualify row_number() over (
        partition by race_id, selection_id
        order by _loaded_at desc, _source_file, _source_row
    ) = 1

)

select * from deduplicated

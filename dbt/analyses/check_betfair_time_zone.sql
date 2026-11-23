/*
    Investigation: in which time zone are Betfair race times?

    Compares the typical (median) first-race time per state, summer vs winter.
    Finding: WA races appear ~2.8h later than NSW in summer and ~2.4h in
    winter, and NZ races ~3h earlier, so ALL times are in Sydney time
    (AEST/AEDT). Confirmed externally: Kembla Grange 10 Jan 2026 start times
    match the Racing NSW race-day preview exactly.
*/

with first_race as (

    select
        meeting_date,
        state_code,
        betfair_track_name,
        min(scheduled_time) as first_race_time
    from {{ ref('stg_betfair__runners') }}
    group by meeting_date, state_code, betfair_track_name

)

select
    state_code,
    case
        when month(meeting_date) in (12, 1, 2) then 'summer'
        when month(meeting_date) in (6, 7, 8)  then 'winter'
    end                                                         as season,
    count(*)                                                    as n_meetings,
    round(median(hour(first_race_time) * 60
               + minute(first_race_time)) / 60, 2)              as median_first_race_hour
from first_race
where month(meeting_date) in (12, 1, 2, 6, 7, 8)
group by state_code, season
order by state_code, season

/*
    Every race must have at least one winner.
    Races with two winners are legitimate dead heats (~0.17% of races in
    2023-2026), so only races with NO winner are treated as an error.
*/

select
    race_id,
    count_if(is_winner) as n_winners
from {{ ref('stg_betfair__runners') }}
group by race_id
having count_if(is_winner) = 0
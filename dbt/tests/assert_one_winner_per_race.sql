/*
    Every race should have exactly one winner.
    Severity is WARN because dead heats (two or more winners) are legitimate.
    Rows returned = races that break the rule.
*/
{{ config(severity='warn') }}

select
    race_id,
    count_if(is_winner) as n_winners
from {{ ref('stg_betfair__runners') }}
group by race_id
having count_if(is_winner) != 1

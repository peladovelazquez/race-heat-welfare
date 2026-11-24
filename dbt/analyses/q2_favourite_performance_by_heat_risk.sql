/*
    Q2 - Do favourites win less often than the market expects on hot days?

    actual_win_pct:   how often the favourite (lowest BSP) actually won.
    expected_win_pct: market expectation = average of 1 / BSP.
    margin_95_pp:     approximate 95% margin of error of actual_win_pct
                      (normal approximation, 1.96 * sqrt(p * (1 - p) / n)).

    A difference smaller than the margin of error is not evidence of an
    effect. Races with joint favourites are excluded.
*/

with races as (

    select *
    from {{ ref('fct_race_conditions') }}
    where favourite_win_bsp is not null
      and not has_joint_favourites

),

summary as (

    select
        heat_policy_level,
        heat_policy_level_rank,
        count(*)                                    as n_races,
        avg(iff(favourite_won, 1, 0))               as actual_rate,
        avg(favourite_implied_probability)          as expected_rate
    from races
    group by heat_policy_level, heat_policy_level_rank

)

select
    heat_policy_level,
    n_races,
    round(100 * actual_rate, 1)                                         as actual_win_pct,
    round(100 * expected_rate, 1)                                       as expected_win_pct,
    round(100 * (actual_rate - expected_rate), 1)                       as difference_pp,
    round(100 * 1.96 * sqrt(actual_rate * (1 - actual_rate) / n_races), 1)
                                                                        as margin_95_pp
from summary
order by heat_policy_level_rank

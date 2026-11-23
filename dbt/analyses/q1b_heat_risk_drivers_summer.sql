/*
    Q1b - Which policy threshold drives heat risk in summer?
    Splits at-risk summer races into: temperature only, WBGT (shade) only,
    or both thresholds.
*/

select
    region,
    count(*)                                                                    as n_races,
    count_if(is_above_temperature_threshold and not is_above_wbgt_threshold)    as temperature_only,
    count_if(is_above_wbgt_threshold and not is_above_temperature_threshold)    as wbgt_only,
    count_if(is_above_temperature_threshold and is_above_wbgt_threshold)        as both_thresholds
from {{ ref('fct_race_conditions') }}
where season = 'Summer'
group by region
order by region

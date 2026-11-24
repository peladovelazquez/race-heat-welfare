/*
    Q1b - Which Level 1 threshold drives heat-policy exposure in summer?
    Splits summer races at Level 1 or above into: temperature only,
    WBGT (shade) only, or both thresholds.
*/

select
    region,
    count(*)                                                        as n_races,
    count_if(is_level1_temperature and not is_level1_wbgt)          as temperature_only,
    count_if(is_level1_wbgt and not is_level1_temperature)          as wbgt_only,
    count_if(is_level1_temperature and is_level1_wbgt)              as both_thresholds
from {{ ref('fct_race_conditions') }}
where season = 'Summer'
group by region
order by region

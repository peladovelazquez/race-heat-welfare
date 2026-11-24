/*
    Q1 - Exposure: share of NSW races run at Racing NSW heat-policy levels,
    by season and region.

    pct_level1_or_above: official metric (WBGT estimated in the shade, as in
                         the policy definition).
    pct_level1_sun:      sensitivity check - Level 1 using the sun WBGT
                         estimate (worst case). The gap shows how much the
                         result depends on the shade/sun assumption.
*/

select
    season,
    region,
    count(*)                                                            as n_races,
    round(100 * count_if(heat_policy_level_rank >= 1) / count(*), 1)    as pct_level1_or_above,
    round(100 * count_if(is_level1_temperature
                         or is_level1_wbgt_sun) / count(*), 1)          as pct_level1_sun,
    count_if(heat_policy_level = 'Level 2')                             as n_level2,
    round(100 * count_if(heat_policy_level = 'Level 2') / count(*), 1)  as pct_level2
from {{ ref('fct_race_conditions') }}
group by season, region
order by
    case season
        when 'Summer' then 1 when 'Autumn' then 2
        when 'Winter' then 3 else 4
    end,
    region

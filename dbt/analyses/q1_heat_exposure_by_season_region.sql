/*
    Q1 - Exposure: share of NSW races run above Racing NSW heat-policy
    thresholds, by season and region.

    pct_at_risk_shade: official metric (WBGT estimated in the shade, as in
                       the policy definition).
    pct_at_risk_sun:   sensitivity check using the sun WBGT estimate
                       (worst case). The gap shows how much the result
                       depends on the shade/sun assumption.
*/

select
    season,
    region,
    count(*)                                                        as n_races,
    round(100 * count_if(heat_risk_level != 'None') / count(*), 1)  as pct_at_risk_shade,
    round(100 * count_if(is_above_temperature_threshold
                         or is_above_wbgt_sun_threshold) / count(*), 1)
                                                                    as pct_at_risk_sun,
    count_if(heat_risk_level = 'High')                              as n_high,
    round(100 * count_if(heat_risk_level = 'High') / count(*), 1)   as pct_high
from {{ ref('fct_race_conditions') }}
group by season, region
order by
    case season
        when 'Summer' then 1 when 'Autumn' then 2
        when 'Winter' then 3 else 4
    end,
    region

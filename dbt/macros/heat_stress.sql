{#
    Heat-stress estimates from air temperature (C) and relative humidity (%).
    None of these use on-course measurements: inputs are hourly gridded
    reanalysis data (Open-Meteo / ERA5), so treat the outputs as indicators.
#}


{#
    Wet-bulb temperature (C), Stull (2011) empirical formula.
    Valid for RH 5-99% and air temperature -20 to 50 C; mean absolute error
    below ~0.3 C in that range.
#}
{% macro estimate_wet_bulb(temperature_c, relative_humidity_pct) -%}
    (
        {{ temperature_c }} * atan(0.151977 * sqrt({{ relative_humidity_pct }} + 8.313659))
        + atan({{ temperature_c }} + {{ relative_humidity_pct }})
        - atan({{ relative_humidity_pct }} - 1.676331)
        + 0.00391838 * power({{ relative_humidity_pct }}, 1.5) * atan(0.023101 * {{ relative_humidity_pct }})
        - 4.686035
    )
{%- endmacro %}


{#
    WBGT in the SHADE (C): 0.7 * wet bulb + 0.3 * air temperature.
    With no direct sun the globe temperature is close to air temperature.
    This is the estimate compared with the Racing NSW policy threshold,
    which refers to "WBGT shade".
#}
{% macro estimate_wbgt_shade(temperature_c, relative_humidity_pct) -%}
    round(
        0.7 * {{ estimate_wet_bulb(temperature_c, relative_humidity_pct) }}
        + 0.3 * {{ temperature_c }},
        1
    )
{%- endmacro %}


{#
    WBGT in the SUN (C), Australian Bureau of Meteorology approximation:
        WBGT = 0.567 * Ta + 0.393 * e + 3.94
        e    = (RH / 100) * 6.105 * exp(17.27 * Ta / (237.7 + Ta))   -- vapour pressure, hPa
    It ignores wind and solar radiation and assumes light winds and fairly
    sunny conditions. Kept as a worst-case reference (sensitivity analysis).
#}
{% macro estimate_wbgt_sun(temperature_c, relative_humidity_pct) -%}
    round(
        0.567 * {{ temperature_c }}
        + 0.393 * (
            {{ relative_humidity_pct }} / 100
            * 6.105 * exp(17.27 * {{ temperature_c }} / (237.7 + {{ temperature_c }}))
        )
        + 3.94,
        1
    )
{%- endmacro %}

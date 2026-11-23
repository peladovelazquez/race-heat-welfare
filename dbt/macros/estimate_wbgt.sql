{#
    Estimated Wet Bulb Globe Temperature (WBGT, degrees C) from air temperature
    and relative humidity, using the Australian Bureau of Meteorology
    approximation:

        WBGT = 0.567 * Ta + 0.393 * e + 3.94
        e    = (RH / 100) * 6.105 * exp(17.27 * Ta / (237.7 + Ta))   -- vapour pressure, hPa

    Limitations: it ignores wind and solar radiation (it assumes light winds
    and fairly sunny conditions), and the inputs come from gridded reanalysis
    data, not on-course measurements. Treat it as an indicator, not a reading.
#}
{% macro estimate_wbgt(temperature_c, relative_humidity_pct) -%}
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

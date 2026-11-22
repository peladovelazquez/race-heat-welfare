{#
    Use the custom schema name as-is (e.g. STAGING, MARTS) instead of dbt's
    default <target_schema>_<custom_schema> (e.g. STAGING_MARTS).
    The schemas themselves are created and secured by DCM, so dbt must write
    exactly into them.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim | upper }}
    {%- endif -%}
{%- endmacro %}

-- =============================================================================
-- Per-environment infrastructure: database, schemas (layers) and warehouse.
-- {{env}} renders as DEV or PROD depending on the target.
-- =============================================================================

DEFINE DATABASE RACING_{{env}}
    COMMENT = 'race-heat-welfare - {{env}} environment';

-- Pipeline layers
{% set layers = {
    'RAW':     'Data as received from the sources (all VARCHAR)',
    'STAGING': 'Cleaning and typing - dbt stg_ models',
    'MARTS':   'Final models for analysis and the dashboard'
} %}

{% for layer, description in layers.items() %}
DEFINE SCHEMA RACING_{{env}}.{{layer}}
    COMMENT = '{{description}}';
{% endfor %}

-- Working warehouse (loading + transformations)
DEFINE WAREHOUSE RACING_WH_{{env}}
    WITH
        warehouse_size = '{{wh_size}}'
        auto_suspend   = {{wh_auto_suspend}}
        auto_resume    = TRUE
        comment        = 'Loading and transformations - {{env}} environment';

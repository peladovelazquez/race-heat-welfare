-- =============================================================================
-- Role-based access control (RBAC) per environment.
--
-- RACING_<ENV>_ENGINEER: day-to-day working role (load data into RAW and run
-- dbt on STAGING / MARTS). It cannot create or drop infrastructure: that is
-- RACING_DEPLOYER's job, via DCM.
-- =============================================================================

DEFINE ROLE RACING_{{env}}_ENGINEER
    COMMENT = 'Data loading and dbt transformations - {{env}} environment';

-- Hierarchy: every custom role rolls up to SYSADMIN
GRANT ROLE RACING_{{env}}_ENGINEER TO ROLE SYSADMIN;

-- Warehouse and database
GRANT USAGE ON WAREHOUSE RACING_WH_{{env}} TO ROLE RACING_{{env}}_ENGINEER;
GRANT USAGE ON DATABASE  RACING_{{env}}    TO ROLE RACING_{{env}}_ENGINEER;

-- Schemas
{% for layer in ['RAW', 'STAGING', 'MARTS'] %}
GRANT USAGE ON SCHEMA RACING_{{env}}.{{layer}} TO ROLE RACING_{{env}}_ENGINEER;
{% endfor %}

-- dbt creates tables and views in STAGING and MARTS
{% for layer in ['STAGING', 'MARTS'] %}
GRANT CREATE TABLE, CREATE VIEW ON SCHEMA RACING_{{env}}.{{layer}} TO ROLE RACING_{{env}}_ENGINEER;
{% endfor %}

-- RAW: use the file format, read/write stages, read/insert into tables
GRANT USAGE ON FILE FORMAT RACING_{{env}}.RAW.FF_CSV TO ROLE RACING_{{env}}_ENGINEER;

{% for stage in ['STG_BETFAIR', 'STG_WEATHER'] %}
GRANT READ, WRITE ON STAGE RACING_{{env}}.RAW.{{stage}} TO ROLE RACING_{{env}}_ENGINEER;
{% endfor %}

{% for table in ['BETFAIR_RUNNERS', 'WEATHER_HOURLY'] %}
GRANT SELECT, INSERT ON TABLE RACING_{{env}}.RAW.{{table}} TO ROLE RACING_{{env}}_ENGINEER;
{% endfor %}

-- =============================================================================
-- 00_bootstrap.sql
-- The minimum that must exist BEFORE DCM Projects can run.
-- Run ONCE, using a connection with ACCOUNTADMIN:
--
--   snow sql -f snowflake/bootstrap/00_bootstrap.sql
--
-- Everything else (databases, schemas, warehouses, project roles, tables...)
-- is defined declaratively in snowflake/dcm/.
-- =============================================================================

-- 1. Role that runs DCM deployments ---------------------------------------------
USE ROLE USERADMIN;

CREATE ROLE IF NOT EXISTS RACING_DEPLOYER
    COMMENT = 'Owner of the race-heat-welfare DCM Projects. Deployments only.';

GRANT ROLE RACING_DEPLOYER TO ROLE SYSADMIN;   -- hierarchy: custom roles roll up to SYSADMIN

SET my_user = CURRENT_USER();
GRANT ROLE RACING_DEPLOYER TO USER IDENTIFIER($my_user);


-- 2. Account-level privileges required by the deployer --------------------------
-- Allows DCM to create the databases, warehouses and roles defined in the project.
-- Account-level privileges must be granted by ACCOUNTADMIN.
USE ROLE ACCOUNTADMIN;

GRANT CREATE DATABASE  ON ACCOUNT TO ROLE RACING_DEPLOYER;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE RACING_DEPLOYER;
GRANT CREATE ROLE      ON ACCOUNT TO ROLE RACING_DEPLOYER;


-- 3. Warehouse used to run deployments -------------------------------------------
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS RACING_DEPLOY_WH
    WAREHOUSE_SIZE      = 'XSMALL'
    AUTO_SUSPEND        = 60
    AUTO_RESUME         = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for DCM PLAN/DEPLOY';

GRANT OWNERSHIP ON WAREHOUSE RACING_DEPLOY_WH TO ROLE RACING_DEPLOYER COPY CURRENT GRANTS;


-- 4. Admin database that holds the DCM Project objects ---------------------------
CREATE DATABASE IF NOT EXISTS RACING_ADMIN
    COMMENT = 'Project administration objects (DCM Projects)';

DROP SCHEMA IF EXISTS RACING_ADMIN.PUBLIC;

GRANT OWNERSHIP ON DATABASE RACING_ADMIN TO ROLE RACING_DEPLOYER COPY CURRENT GRANTS;

USE ROLE RACING_DEPLOYER;
CREATE SCHEMA IF NOT EXISTS RACING_ADMIN.DCM
    COMMENT = 'One DCM Project per environment (DEV, PROD)';


-- 5. Cost control: account-level resource monitor -------------------------------
-- Notifies at 75% and suspends warehouses at 100% of the monthly quota.
USE ROLE ACCOUNTADMIN;

CREATE RESOURCE MONITOR IF NOT EXISTS RACING_MONITOR
    WITH CREDIT_QUOTA = 20
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 75  PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

ALTER ACCOUNT SET RESOURCE_MONITOR = RACING_MONITOR;


-- Check ------------------------------------------------------------------------
SHOW GRANTS TO ROLE RACING_DEPLOYER;

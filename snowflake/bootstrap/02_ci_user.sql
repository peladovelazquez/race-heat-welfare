-- One-off setup: service user for GitHub Actions (key-pair auth, no password).
-- Run with:
--   snow sql -c racing -f snowflake/bootstrap/02_ci_user.sql \
--     -D "ci_public_key=$(grep -v -- '-----' ~/.snowflake/keys/racing_ci.pub | tr -d '\n')"

-- USERADMIN creates users and owns RACING_DEPLOYER.
USE ROLE USERADMIN;

CREATE USER IF NOT EXISTS RACING_CI_USER
    TYPE = SERVICE                      -- service users cannot log in with a password
    RSA_PUBLIC_KEY = '<% ci_public_key %>'
    DEFAULT_ROLE = RACING_DEV_ENGINEER
    DEFAULT_WAREHOUSE = RACING_WH_DEV
    COMMENT = 'GitHub Actions: dcm plan/deploy and dbt build';

-- Infrastructure changes (dcm plan / deploy).
GRANT ROLE RACING_DEPLOYER TO USER RACING_CI_USER;

-- Environment roles are owned by RACING_DEPLOYER (created by DCM).
USE ROLE RACING_DEPLOYER;
GRANT ROLE RACING_DEV_ENGINEER TO USER RACING_CI_USER;
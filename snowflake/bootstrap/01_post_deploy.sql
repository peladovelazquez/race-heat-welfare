-- =============================================================================
-- 01_post_deploy.sql
-- After the FIRST deploy of each environment: grant yourself the working role.
-- (DCM manages roles and role-to-role grants, but not role-to-user grants.)
--
--   snow sql -f snowflake/bootstrap/01_post_deploy.sql -D "env=DEV"
-- =============================================================================

USE ROLE RACING_DEPLOYER;

SET my_user = CURRENT_USER();
GRANT ROLE RACING_<% env %>_ENGINEER TO USER IDENTIFIER($my_user);

SHOW GRANTS TO ROLE RACING_<% env %>_ENGINEER;

-- Verify schemas/app_scope/schema  on pg

BEGIN;

SELECT assert_schema('app_scope'::regnamespace);

ROLLBACK;

-- Verify schemas/metaschema_modules_public/schema on pg

BEGIN;

SELECT assert_schema('metaschema_modules_public'::regnamespace);

ROLLBACK;

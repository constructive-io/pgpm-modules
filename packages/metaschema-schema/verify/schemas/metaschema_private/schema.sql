-- Verify schemas/metaschema_private/schema  on pg

BEGIN;

SELECT assert_schema('metaschema_private'::regnamespace);

ROLLBACK;

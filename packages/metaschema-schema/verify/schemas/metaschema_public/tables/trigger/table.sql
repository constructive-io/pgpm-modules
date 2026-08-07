-- Verify schemas/metaschema_public/tables/trigger/table on pg

BEGIN;

SELECT assert_table('metaschema_public.trigger'::regclass);

ROLLBACK;

-- Verify schemas/metaschema_public/tables/enum/table on pg

BEGIN;

SELECT assert_table('metaschema_public.enum'::regclass);

ROLLBACK;


BEGIN;

SELECT assert_index('metaschema_public.databases_table_unique_name_idx'::regclass, 'metaschema_public.table'::regclass, true);

ROLLBACK;

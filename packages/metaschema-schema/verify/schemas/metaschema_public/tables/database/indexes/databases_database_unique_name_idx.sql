
BEGIN;

SELECT assert_index('metaschema_public.databases_database_unique_name_idx'::regclass, 'metaschema_public.database'::regclass, true);

ROLLBACK;

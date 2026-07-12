
BEGIN;

SELECT verify_table ('metaschema_public.database');
SELECT verify_index ('metaschema_public.database', 'databases_database_platform_singleton_idx');

ROLLBACK;

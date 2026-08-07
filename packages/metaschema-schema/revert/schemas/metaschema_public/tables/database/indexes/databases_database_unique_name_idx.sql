-- Revert schemas/metaschema_public/tables/database/indexes/databases_database_unique_name_idx from pg

BEGIN;

DROP INDEX metaschema_public.databases_database_unique_name_idx;
DROP FUNCTION metaschema_private.database_name_hash(text);

COMMIT;

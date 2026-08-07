-- Revert schemas/metaschema_public/tables/table/indexes/databases_table_unique_name_idx from pg

BEGIN;

DROP INDEX metaschema_public.databases_table_unique_name_idx;
DROP FUNCTION metaschema_private.table_name_hash(text);

COMMIT;

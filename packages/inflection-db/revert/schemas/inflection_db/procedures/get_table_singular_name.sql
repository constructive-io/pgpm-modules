-- Revert schemas/inflection_db/procedures/get_table_singular_name from pg

BEGIN;

DROP FUNCTION inflection_db.get_table_singular_name(text);

COMMIT;

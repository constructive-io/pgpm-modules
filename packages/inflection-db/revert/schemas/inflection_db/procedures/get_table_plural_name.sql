-- Revert schemas/inflection_db/procedures/get_table_plural_name from pg

BEGIN;

DROP FUNCTION inflection_db.get_table_plural_name(text);

COMMIT;

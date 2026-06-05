-- Revert schemas/inflection_db/procedures/get_table_name from pg

BEGIN;

DROP FUNCTION inflection_db.get_table_name (text);
DROP FUNCTION inflection_db.get_table_name (text[]);

COMMIT;

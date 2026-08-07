-- Revert schemas/inflection_db/procedures/get_schema_name from pg

BEGIN;

DROP FUNCTION inflection_db.get_schema_name(text[]);

COMMIT;

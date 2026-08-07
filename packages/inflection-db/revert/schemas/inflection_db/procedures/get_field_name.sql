-- Revert schemas/inflection_db/procedures/get_field_name from pg

BEGIN;

DROP FUNCTION inflection_db.get_field_name(text[]);
DROP FUNCTION inflection_db.get_field_name(text);

COMMIT;

-- Revert schemas/inflection_db/procedures/get_foreign_key_field_name from pg

BEGIN;

DROP FUNCTION inflection_db.get_foreign_key_field_name(text);

COMMIT;

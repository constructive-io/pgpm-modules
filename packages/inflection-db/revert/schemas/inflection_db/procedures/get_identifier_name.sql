-- Revert schemas/inflection_db/procedures/get_identifier_name from pg

BEGIN;

DROP FUNCTION inflection_db.get_identifier_name(text[]);
DROP FUNCTION inflection_db.get_identifier_name(text);

COMMIT;

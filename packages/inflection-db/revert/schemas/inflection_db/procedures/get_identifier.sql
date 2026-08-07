-- Revert schemas/inflection_db/procedures/get_identifier from pg

BEGIN;

DROP FUNCTION inflection_db.get_identifier(text);

COMMIT;

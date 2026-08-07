-- Revert schemas/inflection_db/procedures/get_namespace_name from pg

BEGIN;

DROP FUNCTION inflection_db.get_namespace_name(text[]);

COMMIT;

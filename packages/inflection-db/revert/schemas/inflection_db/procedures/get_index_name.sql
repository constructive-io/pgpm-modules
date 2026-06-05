-- Revert schemas/inflection_db/procedures/get_index_name from pg

BEGIN;

DROP FUNCTION inflection_db.get_index_name;

COMMIT;

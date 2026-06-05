-- Revert schemas/inflection_db/procedures/get_check_constraint_name from pg

BEGIN;

DROP FUNCTION inflection_db.get_check_constraint_name;

COMMIT;

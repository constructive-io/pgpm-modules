-- Verify schemas/inflection_db/procedures/get_check_constraint_name  on pg

BEGIN;

SELECT verify_function ('inflection_db.get_check_constraint_name');

ROLLBACK;

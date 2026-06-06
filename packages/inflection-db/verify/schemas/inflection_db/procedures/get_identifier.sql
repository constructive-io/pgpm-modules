-- Verify schemas/inflection_db/procedures/get_identifier  on pg

BEGIN;

SELECT verify_function ('inflection_db.get_identifier');

ROLLBACK;

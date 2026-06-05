-- Verify schemas/inflection_db/procedures/get_identifier_name on pg

BEGIN;

SELECT verify_function ('inflection_db.get_identifier_name');

ROLLBACK;

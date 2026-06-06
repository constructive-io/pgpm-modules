-- Verify schemas/inflection_db/procedures/get_field_name  on pg

BEGIN;

SELECT verify_function ('inflection_db.get_field_name');

ROLLBACK;

-- Verify schemas/inflection_db/procedures/get_namespace_name on pg

BEGIN;

SELECT inflection_db.get_namespace_name(ARRAY['test']::text[]);

ROLLBACK;

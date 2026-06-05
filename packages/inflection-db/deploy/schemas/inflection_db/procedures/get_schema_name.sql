-- Deploy schemas/inflection_db/procedures/get_schema_name to pg
-- requires: schemas/inflection_db/schema
-- requires: schemas/inflection_db/procedures/get_identifier

BEGIN;
CREATE FUNCTION inflection_db.get_schema_name (parts text[])
  RETURNS text
  AS $$
  SELECT
    inflection_db.get_identifier (inflection.dashed (array_to_string(parts, '-')));
$$
LANGUAGE 'sql'
VOLATILE;
COMMIT;

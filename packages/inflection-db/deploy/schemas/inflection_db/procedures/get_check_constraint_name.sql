-- Deploy schemas/inflection_db/procedures/get_check_constraint_name to pg

-- requires: schemas/inflection_db/schema
-- requires: schemas/inflection_db/procedures/get_table_name
-- requires: schemas/inflection_db/procedures/get_identifier

BEGIN;

CREATE FUNCTION inflection_db.get_check_constraint_name(table_name text, fields text[])
  RETURNS text
  AS $$
  SELECT
    inflection_db.get_identifier (
      inflection.underscore (
        array_to_string(ARRAY[inflection_db.get_table_name (table_name)] || fields || ARRAY['chk'], '_'))
    );
$$
LANGUAGE 'sql'
STABLE;

COMMIT;

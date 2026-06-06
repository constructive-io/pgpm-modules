-- Deploy schemas/inflection_db/procedures/get_index_name to pg
-- requires: schemas/inflection_db/schema
-- requires: schemas/inflection_db/procedures/get_table_name
-- requires: schemas/inflection_db/procedures/get_identifier

BEGIN;
-- ${table_name}_${field1}_${field2}_${fieldN}_idx
CREATE FUNCTION inflection_db.get_index_name (table_name text, fields text[])
  RETURNS text
  AS $$
  SELECT
    inflection_db.get_identifier (inflection.underscore (array_to_string(ARRAY[inflection_db.get_table_name (table_name)] || fields || ARRAY['idx'], '_')));
$$
LANGUAGE 'sql'
STABLE;
COMMIT;


-- Deploy schemas/inflection_db/procedures/get_foreign_key_index_name to pg
-- requires: schemas/inflection_db/schema
-- requires: schemas/inflection_db/procedures/get_table_name
-- requires: schemas/inflection_db/procedures/get_identifier

BEGIN;
-- ${table_name}_${field}_fkey
CREATE FUNCTION inflection_db.get_foreign_key_index_name (table_name text, field text)
  RETURNS text
  AS $$
  SELECT
    inflection_db.get_identifier (inflection.underscore (array_to_string(ARRAY[inflection_db.get_table_name (table_name)] || ARRAY[field] || ARRAY['fkey'], '_')));
$$
LANGUAGE 'sql'
STABLE;
COMMIT;

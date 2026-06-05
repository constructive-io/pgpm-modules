-- Deploy schemas/inflection_db/procedures/get_foreign_key_field_name to pg

-- requires: schemas/inflection_db/schema
-- requires: schemas/inflection_db/procedures/get_identifier


BEGIN;

CREATE FUNCTION inflection_db.get_foreign_key_field_name(table_name text)
  RETURNS text
  AS $$
  SELECT
    inflection_db.get_identifier (
      array_to_string(
        ARRAY[inflection.underscore (inflection.singular(table_name)), 'id']
        , '_')
    );
$$
LANGUAGE 'sql'
IMMUTABLE;

COMMIT;

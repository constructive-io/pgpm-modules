\echo Use "CREATE EXTENSION pgpm-inflection-db" to load this file. \quit
CREATE SCHEMA inflection_db;

GRANT USAGE ON SCHEMA inflection_db TO PUBLIC;

ALTER DEFAULT PRIVILEGES IN SCHEMA inflection_db
  GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

CREATE FUNCTION inflection_db.get_identifier(
  str text
) RETURNS text AS $EOFCODE$
  select substring(str FROM 1 FOR 63);
$EOFCODE$ LANGUAGE sql STABLE;

CREATE FUNCTION inflection_db.get_table_name(
  table_name text
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (inflection.plural (inflection.underscore (table_name)));
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION inflection_db.get_table_name(
  parts text[]
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (inflection.plural (inflection.underscore (parts)));
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION inflection_db.get_check_constraint_name(
  table_name text,
  fields text[]
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (
      inflection.underscore (
        array_to_string(ARRAY[inflection_db.get_table_name (table_name)] || fields || ARRAY['chk'], '_'))
    );
$EOFCODE$ LANGUAGE sql STABLE;

CREATE FUNCTION inflection_db.get_field_name(
  field_name text
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (inflection.underscore (field_name));
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION inflection_db.get_field_name(
  parts text[]
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (inflection.underscore (parts));
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION inflection_db.get_foreign_key_field_name(
  table_name text
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (
      array_to_string(
        ARRAY[inflection.underscore (inflection.singular(table_name)), 'id']
        , '_')
    );
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION inflection_db.get_foreign_key_index_name(
  table_name text,
  field text
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (inflection.underscore (array_to_string(ARRAY[inflection_db.get_table_name (table_name)] || ARRAY[field] || ARRAY['fkey'], '_')));
$EOFCODE$ LANGUAGE sql STABLE;

CREATE FUNCTION inflection_db.get_identifier_name(
  field_name text
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (inflection.underscore (field_name));
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION inflection_db.get_identifier_name(
  parts text[]
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (inflection.underscore (parts));
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION inflection_db.get_index_name(
  table_name text,
  fields text[]
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (inflection.underscore (array_to_string(ARRAY[inflection_db.get_table_name (table_name)] || fields || ARRAY['idx'], '_')));
$EOFCODE$ LANGUAGE sql STABLE;

CREATE FUNCTION inflection_db.get_primary_key_index_name(
  table_name text
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (inflection.underscore (array_to_string(ARRAY[inflection_db.get_table_name (table_name)] || ARRAY['pkey'], '_')));
$EOFCODE$ LANGUAGE sql STABLE;

CREATE FUNCTION inflection_db.get_schema_name(
  parts text[]
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (inflection.dashed (array_to_string(parts, '-')));
$EOFCODE$ LANGUAGE sql VOLATILE;

CREATE FUNCTION inflection_db.get_table_plural_name(
  table_name text
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (inflection.plural (inflection.underscore (table_name)));
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION inflection_db.get_table_singular_name(
  table_name text
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (inflection.singular (inflection.underscore (table_name)));
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION inflection_db.get_unique_index_name(
  table_name text,
  fields text[]
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (
      inflection.underscore (
        array_to_string(ARRAY[inflection_db.get_table_name (table_name)] || fields || ARRAY['key'], '_'))
    );
$EOFCODE$ LANGUAGE sql STABLE;

CREATE FUNCTION inflection_db.get_namespace_name(
  parts text[]
) RETURNS text AS $EOFCODE$
  SELECT
    inflection_db.get_identifier (inflection.underscore (parts));
$EOFCODE$ LANGUAGE sql IMMUTABLE;
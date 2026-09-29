-- Deploy schemas/db_utils/procedures/get_column_smart_comment to pg

-- requires: schemas/db_utils/schema

BEGIN;

CREATE FUNCTION db_utils.get_column_smart_comment(
  schema_name text,
  table_name text,
  column_name text
) returns text as $$
SELECT
  pg_catalog.col_description(attrelid, p.attnum) AS description
FROM
  pg_catalog.pg_attribute p
  INNER JOIN pg_catalog.pg_type t ON (t.oid = p.atttypid)
WHERE
  attrelid = (schema_name || '.' || table_name)::regclass
  AND p.attnum > 0
  AND NOT attisdropped
  AND attname = column_name;
$$
LANGUAGE 'sql' STABLE SECURITY DEFINER;

COMMIT;

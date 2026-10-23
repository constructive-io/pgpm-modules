-- Deploy schemas/reserved_names/procedures/reserved_by to pg

-- requires: schemas/reserved_names/schema
-- requires: schemas/reserved_names/tables/names/table

BEGIN;

CREATE FUNCTION reserved_names.reserved_by(kind text, name text) RETURNS SETOF reserved_names.names AS $$
  SELECT n.*
    FROM reserved_names.names n
   WHERE n.kind = pg_catalog.lower(reserved_by.kind)
     AND CASE n.match
           WHEN 'exact'  THEN n.name = pg_catalog.lower(reserved_by.name)
           WHEN 'prefix' THEN pg_catalog.starts_with(pg_catalog.lower(reserved_by.name), n.name)
           WHEN 'suffix' THEN pg_catalog.right(pg_catalog.lower(reserved_by.name), pg_catalog.length(n.name)) = n.name
         END;
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION reserved_names.reserved_by(text, text) IS 'The entries (with their reason) that reserve name for kind; empty when it is free';

GRANT EXECUTE ON FUNCTION reserved_names.reserved_by(text, text) TO public;

COMMIT;

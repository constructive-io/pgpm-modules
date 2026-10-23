-- Deploy schemas/reserved_names/procedures/is_reserved to pg

-- requires: schemas/reserved_names/schema
-- requires: schemas/reserved_names/tables/names/table

BEGIN;

CREATE FUNCTION reserved_names.is_reserved(kind text, name text) RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1
      FROM reserved_names.names n
     WHERE n.kind = is_reserved.kind
       AND (n.name = pg_catalog.lower(is_reserved.name)
            OR (n.is_prefix AND pg_catalog.starts_with(pg_catalog.lower(is_reserved.name), n.name)))
  );
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION reserved_names.is_reserved(text, text) IS 'True when name (any case) is reserved for kind, exactly or by a prefix entry';

GRANT EXECUTE ON FUNCTION reserved_names.is_reserved(text, text) TO public;

COMMIT;

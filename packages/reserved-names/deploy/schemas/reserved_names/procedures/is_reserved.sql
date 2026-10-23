-- Deploy schemas/reserved_names/procedures/is_reserved to pg

-- requires: schemas/reserved_names/schema
-- requires: schemas/reserved_names/procedures/reserved_by

BEGIN;

CREATE FUNCTION reserved_names.is_reserved(kind text, name text) RETURNS boolean AS $$
  SELECT EXISTS (SELECT 1 FROM reserved_names.reserved_by(is_reserved.kind, is_reserved.name));
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION reserved_names.is_reserved(text, text) IS 'True when name (any case) is reserved for kind';

GRANT EXECUTE ON FUNCTION reserved_names.is_reserved(text, text) TO public;

COMMIT;

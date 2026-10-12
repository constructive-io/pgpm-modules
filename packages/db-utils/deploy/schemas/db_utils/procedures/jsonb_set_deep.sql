-- Deploy schemas/db_utils/procedures/jsonb_set_deep to pg

-- requires: schemas/db_utils/schema

BEGIN;

-- Write `value` at `path` inside `target`, creating any missing intermediate
-- objects. Core `jsonb_set` only creates the LAST path element (create_missing)
-- and returns NULL-ish surprises when an intermediate key is absent or holds a
-- non-object, so it cannot be used to land a declared parameter at a path like
-- `resources.limits.memory` on a spec that has no `resources` yet.
--
-- A non-object sitting at an intermediate key is replaced by an object: the
-- declared binding is authoritative about the shape of the path it owns. The
-- one exception is an array addressed by a numeric segment, which is indexed
-- into, so a binding like `storage.0.size` lands on the first declared volume.
CREATE FUNCTION db_utils.jsonb_set_deep(
  target jsonb,
  path text[],
  value jsonb
) RETURNS jsonb AS $$
DECLARE
  head text;
  rest text[];
  base jsonb;
  child jsonb;
BEGIN
  IF path IS NULL OR array_length(path, 1) IS NULL THEN
    RETURN value;
  END IF;

  head := path[1];
  rest := path[2:array_length(path, 1)];

  base := CASE
    WHEN jsonb_typeof(target) = 'array' AND head ~ '^[0-9]+$' THEN target
    WHEN target IS NULL OR jsonb_typeof(target) <> 'object' THEN '{}'::jsonb
    ELSE target
  END;

  IF array_length(rest, 1) IS NULL THEN
    RETURN jsonb_set(base, ARRAY[head], value, true);
  END IF;

  child := CASE
    WHEN jsonb_typeof(base) = 'array' THEN base -> head::int
    ELSE base -> head
  END;
  RETURN jsonb_set(
    base,
    ARRAY[head],
    db_utils.jsonb_set_deep(child, rest, value),
    true
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMIT;

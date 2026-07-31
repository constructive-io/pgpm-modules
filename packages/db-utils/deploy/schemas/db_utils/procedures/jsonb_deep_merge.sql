-- Deploy schemas/db_utils/procedures/jsonb_deep_merge to pg

-- requires: schemas/db_utils/schema

BEGIN;

-- Recursive object merge: `patch` wins, except where BOTH sides hold an
-- object at the same key, in which case the two objects are merged one level
-- deeper. Everything else (scalars, arrays, type mismatches) is replaced
-- wholesale, and a JSON null in the patch is a deliberate null, not a
-- deletion.
--
-- This is the semantic `||` lacks: `{a:{x:1,y:2}} || {a:{x:9}}` drops `y`,
-- while this merge keeps it. Resource specs are nested objects (settings,
-- resources.requests/limits), so a promoted parameter that touches one leaf
-- must not silently erase its siblings.
CREATE FUNCTION db_utils.jsonb_deep_merge(
  base jsonb,
  patch jsonb
) RETURNS jsonb AS $$
  SELECT CASE
    WHEN base IS NULL THEN patch
    WHEN patch IS NULL THEN base
    WHEN jsonb_typeof(base) <> 'object' OR jsonb_typeof(patch) <> 'object' THEN patch
    ELSE COALESCE(
      (
        SELECT jsonb_object_agg(
          key,
          CASE
            WHEN jsonb_typeof(base -> key) = 'object' AND jsonb_typeof(patch -> key) = 'object'
              THEN db_utils.jsonb_deep_merge(base -> key, patch -> key)
            WHEN patch ? key THEN patch -> key
            ELSE base -> key
          END
        )
        FROM (
          SELECT jsonb_object_keys(base) AS key
          UNION
          SELECT jsonb_object_keys(patch) AS key
        ) AS keys
      ),
      '{}'::jsonb
    )
  END;
$$ LANGUAGE sql IMMUTABLE;

COMMIT;

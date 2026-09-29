\echo Use "CREATE EXTENSION db-utils" to load this file. \quit
CREATE SCHEMA db_utils;

GRANT USAGE ON SCHEMA db_utils TO PUBLIC;

ALTER DEFAULT PRIVILEGES IN SCHEMA db_utils
  GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

CREATE FUNCTION db_utils.get_column_smart_comment(
  schema_name text,
  table_name text,
  column_name text
) RETURNS text AS $EOFCODE$
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
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE FUNCTION db_utils.timestamps(
  schema_name text,
  table_name text
) RETURNS void AS $EOFCODE$
BEGIN
  -- Add created_at column (graceful: skip if already exists)
  EXECUTE format('ALTER TABLE %I.%I ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW()', schema_name, table_name);

  -- Add updated_at column (graceful: skip if already exists)
  EXECUTE format('ALTER TABLE %I.%I ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW()', schema_name, table_name);

  -- Create trigger for timestamps (drop first if exists to stay idempotent)
  EXECUTE format('DROP TRIGGER IF EXISTS timestamps_tg ON %I.%I', schema_name, table_name);
  EXECUTE format('CREATE TRIGGER timestamps_tg BEFORE UPDATE OR INSERT ON %I.%I FOR EACH ROW EXECUTE PROCEDURE stamps.timestamps()', schema_name, table_name);

  -- Create indexes (skip if an index on the column already exists)
  PERFORM 1 FROM pg_index i
    JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
    WHERE i.indrelid = format('%I.%I', schema_name, table_name)::regclass
    AND a.attname = 'created_at';
  IF NOT FOUND THEN
    EXECUTE format('CREATE INDEX ON %I.%I (created_at)', schema_name, table_name);
  END IF;

  PERFORM 1 FROM pg_index i
    JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
    WHERE i.indrelid = format('%I.%I', schema_name, table_name)::regclass
    AND a.attname = 'updated_at';
  IF NOT FOUND THEN
    EXECUTE format('CREATE INDEX ON %I.%I (updated_at)', schema_name, table_name);
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION db_utils.jsonb_deep_merge(
  base jsonb,
  patch jsonb
) RETURNS jsonb AS $EOFCODE$
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
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION db_utils.jsonb_set_deep(
  target jsonb,
  path text[],
  value jsonb
) RETURNS jsonb AS $EOFCODE$
DECLARE
  head text;
  rest text[];
  base jsonb;
  child jsonb;
BEGIN
  IF path IS NULL OR array_length(path, 1) IS NULL THEN
    RETURN value;
  END IF;

  base := CASE
    WHEN target IS NULL OR jsonb_typeof(target) <> 'object' THEN '{}'::jsonb
    ELSE target
  END;

  head := path[1];
  rest := path[2:array_length(path, 1)];

  IF array_length(rest, 1) IS NULL THEN
    RETURN jsonb_set(base, ARRAY[head], value, true);
  END IF;

  child := base -> head;
  RETURN jsonb_set(
    base,
    ARRAY[head],
    db_utils.jsonb_set_deep(child, rest, value),
    true
  );
END;
$EOFCODE$ LANGUAGE plpgsql IMMUTABLE;
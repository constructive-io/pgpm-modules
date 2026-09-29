-- Deploy schemas/db_utils/procedures/timestamps to pg

-- requires: schemas/db_utils/schema

BEGIN;

CREATE FUNCTION db_utils.timestamps(
  schema_name text,
  table_name text
) RETURNS void AS $$
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
$$ LANGUAGE plpgsql VOLATILE;

COMMIT;

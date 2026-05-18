-- Deploy schemas/partman/procedures/create_parent_by_id to pg

-- requires: extensions/pg_partman

BEGIN;

CREATE FUNCTION partman.create_parent_by_id(
  v_table_id uuid,
  v_control text,
  v_type text DEFAULT 'range',
  partition_interval text DEFAULT '1 day',
  v_premake int DEFAULT 2
) RETURNS void AS $$
DECLARE
  v_parent_table text;
BEGIN
  SELECT s.schema_name || '.' || t.name INTO v_parent_table
    FROM metaschema_public.table t
    JOIN metaschema_public.schema s
      ON (s.id = t.schema_id AND s.database_id = t.database_id)
    WHERE t.id = v_table_id;

  IF v_parent_table IS NULL THEN
    RAISE EXCEPTION 'partman.create_parent_by_id: table_id % not found', v_table_id;
  END IF;

  PERFORM partman.create_parent(
    p_parent_table := v_parent_table,
    p_control := v_control,
    p_type := v_type,
    p_interval := partition_interval,
    p_premake := v_premake
  );
END;
$$
LANGUAGE 'plpgsql' VOLATILE;

COMMIT;

-- Deploy schemas/partman/triggers/after_delete_partition to pg

-- requires: schemas/partman/triggers/after_insert_partition
-- requires: metaschema-schema:schemas/metaschema_public/tables/partition/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table

BEGIN;

-- Inverse of tg_after_insert_partition: unparents the config from pg_partman.
-- create_parent leaves two objects behind that outlive the parent table's own
-- DROP ... CASCADE — the part_config row and the partman.template_<parent>
-- table, whose columns hold the parent's types and so block dropping them.
CREATE FUNCTION partman.tg_after_delete_partition()
RETURNS TRIGGER AS $$
DECLARE
  v_parent_table text;
  v_template_table text;
BEGIN
  SELECT s.schema_name || '.' || t.name
    INTO v_parent_table
    FROM metaschema_public.table t
    JOIN metaschema_public.schema s
      ON (s.id = t.schema_id AND s.database_id = t.database_id)
    WHERE t.id = OLD.table_id;

  IF v_parent_table IS NULL THEN
    RETURN OLD;
  END IF;

  DELETE FROM partman.part_config
    WHERE parent_table = v_parent_table
    RETURNING template_table INTO v_template_table;

  IF v_template_table IS NOT NULL AND to_regclass(v_template_table) IS NOT NULL THEN
    -- pgsql-lint-disable-next-line no-dynamic-sql -- DDL on a relation named by partman.part_config.template_table
    EXECUTE format('DROP TABLE %s', to_regclass(v_template_table)::text);
  END IF;

  RETURN OLD;
END;
$$
LANGUAGE 'plpgsql' VOLATILE SECURITY DEFINER;

-- SECURITY DEFINER justification: mirrors create_parent_with_retention. The
-- template table is owned by postgres (create_parent reassigns it), so the
-- authenticated role cannot drop it without SET ROLE. The function touches
-- only partman.part_config and the template table it names — never user data.

CREATE TRIGGER partman_after_delete_partition
  AFTER DELETE ON metaschema_public.partition
  FOR EACH ROW
  EXECUTE PROCEDURE partman.tg_after_delete_partition();

COMMIT;

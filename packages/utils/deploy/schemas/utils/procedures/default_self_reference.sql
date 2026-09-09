-- Deploy schemas/utils/procedures/default_self_reference to pg

-- requires: schemas/utils/schema

BEGIN;

-- BEFORE INSERT trigger function that defaults a self-referencing column to
-- the row's own id when the insert leaves it NULL. Lets a tree table keep the
-- column NOT NULL while callers only supply it for non-root rows.
--
-- TG_ARGV[0] : name of the column to default to NEW.id
CREATE FUNCTION utils.default_self_reference()
  RETURNS TRIGGER
AS $$
DECLARE
  column_name text := TG_ARGV[0];
BEGIN
  IF (to_jsonb(NEW) ->> column_name) IS NULL THEN
    NEW := jsonb_populate_record(NEW, jsonb_build_object(column_name, NEW.id));
  END IF;

  RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

COMMIT;

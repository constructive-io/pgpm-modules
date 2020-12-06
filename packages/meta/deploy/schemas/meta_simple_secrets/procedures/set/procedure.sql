-- Deploy: schemas/meta_simple_secrets/procedures/set/procedure to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_simple_secrets/schema
-- requires: schemas/meta_simple_secrets/tables/user_secrets/table

BEGIN;

CREATE FUNCTION "meta_simple_secrets".set (
  v_owner_id uuid,
  v_secret_name text,
  v_value anyelement
)
  RETURNS void
  AS $$
    INSERT INTO "meta_simple_secrets".user_secrets 
        (owner_id, name, value)
    VALUES
        (set.v_owner_id, set.v_secret_name, set.v_value::text)
    ON CONFLICT (owner_id, name)
    DO UPDATE 
    SET value = EXCLUDED.value;
$$
LANGUAGE 'sql'
VOLATILE;
GRANT EXECUTE ON FUNCTION "meta_simple_secrets".set TO authenticated;
COMMIT;

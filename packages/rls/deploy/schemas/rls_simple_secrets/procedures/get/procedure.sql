-- Deploy: schemas/rls_simple_secrets/procedures/get/procedure to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_simple_secrets/schema
-- requires: schemas/rls_simple_secrets/tables/user_secrets/table

BEGIN;

CREATE FUNCTION "rls_simple_secrets".get (
  v_owner_id uuid,
  v_secret_name text,
  v_default_value text default null
)
  RETURNS text
  AS $$
DECLARE
    val text;
BEGIN
    SELECT value FROM "rls_simple_secrets".user_secrets t 
        WHERE t.owner_id = get.v_owner_id
        AND t.name = get.v_secret_name
    INTO val;
    IF (NOT FOUND OR val IS NULL) THEN
        RETURN v_default_value;
    END IF;
    RETURN val;
END;
$$
LANGUAGE 'plpgsql'
STABLE;
GRANT EXECUTE ON FUNCTION "rls_simple_secrets".get TO authenticated;
COMMIT;

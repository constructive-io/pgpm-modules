-- Deploy: schemas/rls_roles_public/procedures/get_current_group_ids/procedure to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_public/schema

BEGIN;

CREATE FUNCTION "rls_roles_public".get_current_group_ids ()
  RETURNS uuid[]
AS $$
DECLARE
  v_identifier_ids uuid[];
BEGIN
  IF current_setting('jwt.claims.group_ids', TRUE)
    IS NOT NULL THEN
    BEGIN
      v_identifier_ids = current_setting('jwt.claims.group_ids', TRUE)::uuid[];
    EXCEPTION
      WHEN OTHERS THEN
      RAISE NOTICE 'Invalid UUID value';
    RETURN ARRAY[]::uuid[];
    END;
    RETURN v_identifier_ids;
  ELSE
    RETURN ARRAY[]::uuid[];
  END IF;
END;
$$
LANGUAGE 'plpgsql' STABLE;
COMMIT;

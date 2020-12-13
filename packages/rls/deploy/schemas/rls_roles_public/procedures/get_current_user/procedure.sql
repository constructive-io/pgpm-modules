-- Deploy: schemas/rls_roles_public/procedures/get_current_user/procedure to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_public/schema
-- requires: schemas/rls_public/tables/users/table

BEGIN;

CREATE FUNCTION "rls_roles_public".get_current_user()
    RETURNS "rls_public".users
AS $$
DECLARE
  v_user "rls_public".users;
BEGIN
  IF "rls_roles_public".get_current_user_id() IS NOT NULL THEN
     SELECT * FROM "rls_public".users WHERE id = "rls_roles_public".get_current_user_id() INTO v_user;
     RETURN v_user;
  ELSE
     RETURN NULL;
  END IF;
END;
$$
LANGUAGE 'plpgsql' STABLE;
COMMIT;

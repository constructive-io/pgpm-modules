-- Deploy: schemas/rls_roles_public/procedures/get_current_user/grants/authenticated to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_public/schema
-- requires: schemas/rls_roles_public/procedures/get_current_user/procedure

BEGIN;

GRANT EXECUTE ON FUNCTION
    "rls_roles_public".get_current_user
TO authenticated;
COMMIT;

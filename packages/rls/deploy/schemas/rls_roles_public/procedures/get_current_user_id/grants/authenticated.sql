-- Deploy: schemas/rls_roles_public/procedures/get_current_user_id/grants/authenticated to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_public/schema
-- requires: schemas/rls_roles_public/procedures/get_current_user_id/procedure

BEGIN;

GRANT EXECUTE ON FUNCTION
    "rls_roles_public".get_current_user_id
TO authenticated;
COMMIT;

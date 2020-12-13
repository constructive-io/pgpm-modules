-- Deploy: schemas/rls_roles_public/procedures/get_current_group_ids/grants/authenticated to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_public/schema
-- requires: schemas/rls_roles_public/procedures/get_current_group_ids/procedure

BEGIN;

GRANT EXECUTE ON FUNCTION
    "rls_roles_public".get_current_group_ids
TO authenticated;
COMMIT;

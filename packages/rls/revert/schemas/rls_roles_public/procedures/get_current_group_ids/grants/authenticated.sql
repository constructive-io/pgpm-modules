-- Revert: schemas/rls_roles_public/procedures/get_current_group_ids/grants/authenticated from pg

BEGIN;


REVOKE EXECUTE ON FUNCTION
    "rls_roles_public".get_current_group_ids
FROM authenticated;
COMMIT;  


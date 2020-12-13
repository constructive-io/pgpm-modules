-- Revert: schemas/rls_roles_private/tables/api_tokens/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE "rls_roles_private".api_tokens FROM authenticated;
COMMIT;  


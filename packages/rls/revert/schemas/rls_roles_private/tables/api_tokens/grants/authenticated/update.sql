-- Revert: schemas/rls_roles_private/tables/api_tokens/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE "rls_roles_private".api_tokens FROM authenticated;
COMMIT;  


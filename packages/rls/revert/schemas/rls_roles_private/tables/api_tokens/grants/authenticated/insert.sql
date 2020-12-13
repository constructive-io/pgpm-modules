-- Revert: schemas/rls_roles_private/tables/api_tokens/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE "rls_roles_private".api_tokens FROM authenticated;
COMMIT;  


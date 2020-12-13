-- Revert: schemas/rls_roles_private/tables/api_tokens/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE "rls_roles_private".api_tokens FROM authenticated;
COMMIT;  


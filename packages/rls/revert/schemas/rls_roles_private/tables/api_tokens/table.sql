-- Revert: schemas/rls_roles_private/tables/api_tokens/table from pg

BEGIN;
DROP TABLE "rls_roles_private".api_tokens;
COMMIT;  


-- Revert: schemas/rls_roles_private/tables/api_tokens/policies/enable_row_level_security from pg

BEGIN;


ALTER TABLE "rls_roles_private".api_tokens
    DISABLE ROW LEVEL SECURITY;

COMMIT;  


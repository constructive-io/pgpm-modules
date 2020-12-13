-- Revert: schemas/rls_roles_private/tables/api_tokens/alterations/alt0000000016 from pg

BEGIN;


ALTER TABLE "rls_roles_private".api_tokens
    ENABLE ROW LEVEL SECURITY;

COMMIT;  


-- Revert: schemas/rls_roles_private/tables/api_tokens/columns/access_token_expires_at/alterations/alt0000000023 from pg

BEGIN;


ALTER TABLE "rls_roles_private".api_tokens 
    ALTER COLUMN access_token_expires_at DROP DEFAULT;

COMMIT;  


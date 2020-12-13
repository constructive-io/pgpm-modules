-- Revert: schemas/rls_roles_private/tables/api_tokens/constraints/api_tokens_pkey from pg

BEGIN;


ALTER TABLE "rls_roles_private".api_tokens 
    DROP CONSTRAINT api_tokens_pkey;

COMMIT;  


-- Revert: schemas/rls_roles_private/tables/api_tokens/columns/id/alterations/alt0000000017 from pg

BEGIN;


ALTER TABLE "rls_roles_private".api_tokens 
    ALTER COLUMN id DROP NOT NULL;


COMMIT;  


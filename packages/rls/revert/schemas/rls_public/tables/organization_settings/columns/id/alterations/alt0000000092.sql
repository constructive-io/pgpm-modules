-- Revert: schemas/rls_public/tables/organization_settings/columns/id/alterations/alt0000000092 from pg

BEGIN;


ALTER TABLE "rls_public".organization_settings 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  


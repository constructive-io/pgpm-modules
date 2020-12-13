-- Revert: schemas/rls_public/tables/organization_settings/columns/id/alterations/alt0000000091 from pg

BEGIN;


ALTER TABLE "rls_public".organization_settings 
    ALTER COLUMN id DROP NOT NULL;


COMMIT;  


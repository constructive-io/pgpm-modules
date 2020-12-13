-- Revert: schemas/rls_public/tables/organization_settings/columns/organization_id/alterations/alt0000000093 from pg

BEGIN;


ALTER TABLE "rls_public".organization_settings 
    ALTER COLUMN organization_id DROP NOT NULL;


COMMIT;  


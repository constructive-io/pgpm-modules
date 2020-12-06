-- Revert: schemas/meta_public/tables/organization_settings/columns/id/alterations/alt0000000067 from pg

BEGIN;


ALTER TABLE "meta_public".organization_settings 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  


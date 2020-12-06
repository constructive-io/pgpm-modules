-- Revert: schemas/meta_public/tables/organization_settings/columns/organization_id/alterations/alt0000000072 from pg

BEGIN;


ALTER TABLE "meta_public".organization_settings 
    ALTER COLUMN organization_id DROP NOT NULL;


COMMIT;  


-- Revert: schemas/rls_public/tables/organization_settings/constraints/organization_settings_pkey from pg

BEGIN;


ALTER TABLE "rls_public".organization_settings 
    DROP CONSTRAINT organization_settings_pkey;

COMMIT;  


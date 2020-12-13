-- Revert: schemas/rls_public/tables/organization_settings/indexes/organization_settings_organization_id_idx from pg

BEGIN;


DROP INDEX "rls_public".organization_settings_organization_id_idx;

COMMIT;  


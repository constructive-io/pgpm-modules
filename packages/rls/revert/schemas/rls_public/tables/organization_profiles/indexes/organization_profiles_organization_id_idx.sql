-- Revert: schemas/rls_public/tables/organization_profiles/indexes/organization_profiles_organization_id_idx from pg

BEGIN;


DROP INDEX "rls_public".organization_profiles_organization_id_idx;

COMMIT;  


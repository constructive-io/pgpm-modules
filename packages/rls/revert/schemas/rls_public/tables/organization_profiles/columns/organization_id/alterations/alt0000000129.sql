-- Revert: schemas/rls_public/tables/organization_profiles/columns/organization_id/alterations/alt0000000129 from pg

BEGIN;


ALTER TABLE "rls_public".organization_profiles 
    ALTER COLUMN organization_id DROP NOT NULL;


COMMIT;  


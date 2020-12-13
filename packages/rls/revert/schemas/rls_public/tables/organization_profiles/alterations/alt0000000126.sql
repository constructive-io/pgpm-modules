-- Revert: schemas/rls_public/tables/organization_profiles/alterations/alt0000000126 from pg

BEGIN;


ALTER TABLE "rls_public".organization_profiles
    ENABLE ROW LEVEL SECURITY;

COMMIT;  


-- Verify: schemas/rls_public/tables/organization_profiles/table on pg

BEGIN;
SELECT verify_table('rls_public.organization_profiles');
COMMIT;  


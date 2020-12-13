-- Verify: schemas/rls_public/tables/organization_profiles/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('rls_public.organization_profiles', 'update', 'authenticated');
COMMIT;  


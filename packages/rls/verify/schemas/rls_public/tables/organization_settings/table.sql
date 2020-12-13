-- Verify: schemas/rls_public/tables/organization_settings/table on pg

BEGIN;
SELECT verify_table('rls_public.organization_settings');
COMMIT;  


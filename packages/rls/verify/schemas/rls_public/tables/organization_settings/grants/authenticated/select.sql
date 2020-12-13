-- Verify: schemas/rls_public/tables/organization_settings/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('rls_public.organization_settings', 'select', 'authenticated');
COMMIT;  


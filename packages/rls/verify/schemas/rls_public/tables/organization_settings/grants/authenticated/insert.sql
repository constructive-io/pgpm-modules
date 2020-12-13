-- Verify: schemas/rls_public/tables/organization_settings/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('rls_public.organization_settings', 'insert', 'authenticated');
COMMIT;  


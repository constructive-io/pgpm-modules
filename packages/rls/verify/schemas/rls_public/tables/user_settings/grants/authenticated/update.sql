-- Verify: schemas/rls_public/tables/user_settings/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('rls_public.user_settings', 'update', 'authenticated');
COMMIT;  


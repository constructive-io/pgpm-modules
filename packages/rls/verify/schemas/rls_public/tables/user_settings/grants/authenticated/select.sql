-- Verify: schemas/rls_public/tables/user_settings/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('rls_public.user_settings', 'select', 'authenticated');
COMMIT;  


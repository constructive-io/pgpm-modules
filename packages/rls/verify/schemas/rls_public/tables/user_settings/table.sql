-- Verify: schemas/rls_public/tables/user_settings/table on pg

BEGIN;
SELECT verify_table('rls_public.user_settings');
COMMIT;  


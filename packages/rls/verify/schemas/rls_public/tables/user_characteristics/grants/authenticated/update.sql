-- Verify: schemas/rls_public/tables/user_characteristics/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('rls_public.user_characteristics', 'update', 'authenticated');
COMMIT;  


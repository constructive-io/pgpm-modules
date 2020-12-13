-- Verify: schemas/rls_public/tables/user_characteristics/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('rls_public.user_characteristics', 'insert', 'authenticated');
COMMIT;  


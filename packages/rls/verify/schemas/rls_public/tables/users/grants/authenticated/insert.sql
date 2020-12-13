-- Verify: schemas/rls_public/tables/users/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('rls_public.users', 'insert', 'authenticated');
COMMIT;  


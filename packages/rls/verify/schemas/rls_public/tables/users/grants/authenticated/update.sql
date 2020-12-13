-- Verify: schemas/rls_public/tables/users/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('rls_public.users', 'update', 'authenticated');
COMMIT;  


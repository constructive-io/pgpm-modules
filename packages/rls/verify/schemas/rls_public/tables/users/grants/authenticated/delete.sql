-- Verify: schemas/rls_public/tables/users/grants/authenticated/delete on pg

BEGIN;
SELECT verify_table_grant('rls_public.users', 'delete', 'authenticated');
COMMIT;  


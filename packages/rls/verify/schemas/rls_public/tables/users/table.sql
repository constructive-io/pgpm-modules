-- Verify: schemas/rls_public/tables/users/table on pg

BEGIN;
SELECT verify_table('rls_public.users');
COMMIT;  


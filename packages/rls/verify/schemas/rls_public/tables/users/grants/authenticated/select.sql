-- Verify: schemas/rls_public/tables/users/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('rls_public.users', 'select', 'authenticated');
COMMIT;  


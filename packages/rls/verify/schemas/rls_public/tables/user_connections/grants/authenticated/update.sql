-- Verify: schemas/rls_public/tables/user_connections/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('rls_public.user_connections', 'update', 'authenticated');
COMMIT;  


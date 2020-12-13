-- Verify: schemas/rls_public/tables/user_connections/table on pg

BEGIN;
SELECT verify_table('rls_public.user_connections');
COMMIT;  


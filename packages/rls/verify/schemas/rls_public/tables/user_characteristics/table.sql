-- Verify: schemas/rls_public/tables/user_characteristics/table on pg

BEGIN;
SELECT verify_table('rls_public.user_characteristics');
COMMIT;  


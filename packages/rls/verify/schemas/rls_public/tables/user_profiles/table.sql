-- Verify: schemas/rls_public/tables/user_profiles/table on pg

BEGIN;
SELECT verify_table('rls_public.user_profiles');
COMMIT;  


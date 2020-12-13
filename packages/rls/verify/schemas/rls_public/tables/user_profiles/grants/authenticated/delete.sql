-- Verify: schemas/rls_public/tables/user_profiles/grants/authenticated/delete on pg

BEGIN;
SELECT verify_table_grant('rls_public.user_profiles', 'delete', 'authenticated');
COMMIT;  


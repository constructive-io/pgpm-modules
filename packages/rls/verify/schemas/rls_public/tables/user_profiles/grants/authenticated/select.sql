-- Verify: schemas/rls_public/tables/user_profiles/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('rls_public.user_profiles', 'select', 'authenticated');
COMMIT;  


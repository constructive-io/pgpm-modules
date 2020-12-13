-- Verify: schemas/rls_public/tables/user_characteristics/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('rls_public.user_characteristics', 'select', 'authenticated');
COMMIT;  


-- Verify: schemas/rls_public/tables/user_contacts/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('rls_public.user_contacts', 'select', 'authenticated');
COMMIT;  


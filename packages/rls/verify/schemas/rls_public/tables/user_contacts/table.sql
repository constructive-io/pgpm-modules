-- Verify: schemas/rls_public/tables/user_contacts/table on pg

BEGIN;
SELECT verify_table('rls_public.user_contacts');
COMMIT;  


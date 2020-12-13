-- Verify: schemas/rls_public/tables/emails/table on pg

BEGIN;
SELECT verify_table('rls_public.emails');
COMMIT;  


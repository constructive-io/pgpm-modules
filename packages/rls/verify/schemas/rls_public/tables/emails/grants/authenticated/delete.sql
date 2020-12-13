-- Verify: schemas/rls_public/tables/emails/grants/authenticated/delete on pg

BEGIN;
SELECT verify_table_grant('rls_public.emails', 'delete', 'authenticated');
COMMIT;  


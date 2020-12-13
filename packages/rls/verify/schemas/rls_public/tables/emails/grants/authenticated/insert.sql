-- Verify: schemas/rls_public/tables/emails/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('rls_public.emails', 'insert', 'authenticated');
COMMIT;  


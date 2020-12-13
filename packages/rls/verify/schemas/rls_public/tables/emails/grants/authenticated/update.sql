-- Verify: schemas/rls_public/tables/emails/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('rls_public.emails', 'update', 'authenticated');
COMMIT;  


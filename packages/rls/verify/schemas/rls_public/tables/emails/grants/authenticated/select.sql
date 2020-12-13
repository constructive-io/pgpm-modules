-- Verify: schemas/rls_public/tables/emails/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('rls_public.emails', 'select', 'authenticated');
COMMIT;  


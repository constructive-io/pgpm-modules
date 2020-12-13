-- Verify: schemas/rls_public/tables/invites/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('rls_public.invites', 'select', 'authenticated');
COMMIT;  


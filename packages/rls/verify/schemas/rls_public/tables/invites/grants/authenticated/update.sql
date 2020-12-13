-- Verify: schemas/rls_public/tables/invites/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('rls_public.invites', 'update', 'authenticated');
COMMIT;  


-- Verify: schemas/rls_public/tables/invites/grants/authenticated/delete on pg

BEGIN;
SELECT verify_table_grant('rls_public.invites', 'delete', 'authenticated');
COMMIT;  


-- Verify: schemas/rls_public/tables/invites/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('rls_public.invites', 'insert', 'authenticated');
COMMIT;  


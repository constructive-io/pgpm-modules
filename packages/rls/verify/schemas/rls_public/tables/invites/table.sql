-- Verify: schemas/rls_public/tables/invites/table on pg

BEGIN;
SELECT verify_table('rls_public.invites');
COMMIT;  


-- Verify: schemas/rls_public/tables/claimed_invites/table on pg

BEGIN;
SELECT verify_table('rls_public.claimed_invites');
COMMIT;  


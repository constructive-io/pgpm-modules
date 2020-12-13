-- Verify: schemas/rls_public/tables/claimed_invites/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('rls_public.claimed_invites', 'select', 'authenticated');
COMMIT;  


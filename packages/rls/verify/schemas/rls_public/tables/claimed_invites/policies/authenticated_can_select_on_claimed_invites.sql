-- Verify: schemas/rls_public/tables/claimed_invites/policies/authenticated_can_select_on_claimed_invites on pg

BEGIN;
SELECT verify_policy('authenticated_can_select_on_claimed_invites', 'rls_public.claimed_invites');
COMMIT;  


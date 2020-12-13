-- Verify: schemas/rls_public/tables/invites/policies/authenticated_can_select_on_invites on pg

BEGIN;
SELECT verify_policy('authenticated_can_select_on_invites', 'rls_public.invites');
COMMIT;  


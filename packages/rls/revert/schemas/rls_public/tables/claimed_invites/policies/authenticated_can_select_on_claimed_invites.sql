-- Revert: schemas/rls_public/tables/claimed_invites/policies/authenticated_can_select_on_claimed_invites from pg

BEGIN;
DROP POLICY authenticated_can_select_on_claimed_invites ON "rls_public".claimed_invites;
COMMIT;  


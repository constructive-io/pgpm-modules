-- Revert: schemas/rls_public/tables/invites/policies/authenticated_can_select_on_invites from pg

BEGIN;
DROP POLICY authenticated_can_select_on_invites ON "rls_public".invites;
COMMIT;  


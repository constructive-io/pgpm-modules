-- Revert: schemas/rls_public/tables/claimed_invites/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE "rls_public".claimed_invites FROM authenticated;
COMMIT;  


-- Revert: schemas/rls_public/tables/invites/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE "rls_public".invites FROM authenticated;
COMMIT;  


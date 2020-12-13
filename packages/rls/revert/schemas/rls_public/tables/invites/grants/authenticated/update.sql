-- Revert: schemas/rls_public/tables/invites/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ( expires_at ) ON TABLE "rls_public".invites FROM authenticated;
COMMIT;  


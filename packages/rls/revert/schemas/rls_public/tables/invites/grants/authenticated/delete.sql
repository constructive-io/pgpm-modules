-- Revert: schemas/rls_public/tables/invites/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE "rls_public".invites FROM authenticated;
COMMIT;  


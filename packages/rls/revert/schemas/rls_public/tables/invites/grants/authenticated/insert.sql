-- Revert: schemas/rls_public/tables/invites/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ( email, invite_limit, multiple, expires_at ) ON TABLE "rls_public".invites FROM authenticated;
COMMIT;  


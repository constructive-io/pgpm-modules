-- Revert: schemas/rls_public/tables/users/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE "rls_public".users FROM authenticated;
COMMIT;  


-- Revert: schemas/rls_public/tables/users/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE "rls_public".users FROM authenticated;
COMMIT;  


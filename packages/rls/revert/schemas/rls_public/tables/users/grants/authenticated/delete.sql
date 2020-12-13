-- Revert: schemas/rls_public/tables/users/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE "rls_public".users FROM authenticated;
COMMIT;  


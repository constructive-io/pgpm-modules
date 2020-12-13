-- Revert: schemas/rls_public/tables/user_connections/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE "rls_public".user_connections FROM authenticated;
COMMIT;  


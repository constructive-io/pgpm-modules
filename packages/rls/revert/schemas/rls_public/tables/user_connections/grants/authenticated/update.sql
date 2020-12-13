-- Revert: schemas/rls_public/tables/user_connections/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ( accepted ) ON TABLE "rls_public".user_connections FROM authenticated;
COMMIT;  


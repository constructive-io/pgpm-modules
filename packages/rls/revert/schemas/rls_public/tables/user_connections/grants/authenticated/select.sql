-- Revert: schemas/rls_public/tables/user_connections/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE "rls_public".user_connections FROM authenticated;
COMMIT;  


-- Revert: schemas/rls_simple_secrets/tables/user_secrets/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE "rls_simple_secrets".user_secrets FROM authenticated;
COMMIT;  


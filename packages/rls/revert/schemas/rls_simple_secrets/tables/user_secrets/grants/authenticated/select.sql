-- Revert: schemas/rls_simple_secrets/tables/user_secrets/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE "rls_simple_secrets".user_secrets FROM authenticated;
COMMIT;  


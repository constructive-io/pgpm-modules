-- Revert: schemas/rls_simple_secrets/tables/user_secrets/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE "rls_simple_secrets".user_secrets FROM authenticated;
COMMIT;  


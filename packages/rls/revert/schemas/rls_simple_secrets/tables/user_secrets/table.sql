-- Revert: schemas/rls_simple_secrets/tables/user_secrets/table from pg

BEGIN;
DROP TABLE "rls_simple_secrets".user_secrets;
COMMIT;  


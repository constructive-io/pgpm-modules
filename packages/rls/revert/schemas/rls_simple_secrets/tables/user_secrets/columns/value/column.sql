-- Revert: schemas/rls_simple_secrets/tables/user_secrets/columns/value/column from pg

BEGIN;


ALTER TABLE "rls_simple_secrets".user_secrets DROP COLUMN value;
COMMIT;  


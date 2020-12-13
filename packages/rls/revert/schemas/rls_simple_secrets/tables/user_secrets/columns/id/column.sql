-- Revert: schemas/rls_simple_secrets/tables/user_secrets/columns/id/column from pg

BEGIN;


ALTER TABLE "rls_simple_secrets".user_secrets DROP COLUMN id;
COMMIT;  


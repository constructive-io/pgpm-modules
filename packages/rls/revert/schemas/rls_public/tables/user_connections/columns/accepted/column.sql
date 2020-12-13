-- Revert: schemas/rls_public/tables/user_connections/columns/accepted/column from pg

BEGIN;


ALTER TABLE "rls_public".user_connections DROP COLUMN accepted;
COMMIT;  


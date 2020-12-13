-- Revert: schemas/rls_public/tables/user_connections/columns/id/column from pg

BEGIN;


ALTER TABLE "rls_public".user_connections DROP COLUMN id;
COMMIT;  


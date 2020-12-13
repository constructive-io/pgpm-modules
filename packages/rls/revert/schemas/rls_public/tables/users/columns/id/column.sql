-- Revert: schemas/rls_public/tables/users/columns/id/column from pg

BEGIN;


ALTER TABLE "rls_public".users DROP COLUMN id;
COMMIT;  


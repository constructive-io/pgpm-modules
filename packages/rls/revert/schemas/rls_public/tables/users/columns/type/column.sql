-- Revert: schemas/rls_public/tables/users/columns/type/column from pg

BEGIN;


ALTER TABLE "rls_public".users DROP COLUMN type;
COMMIT;  


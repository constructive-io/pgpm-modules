-- Revert: schemas/rls_public/tables/addresses/columns/other/column from pg

BEGIN;


ALTER TABLE "rls_public".addresses DROP COLUMN other;
COMMIT;  


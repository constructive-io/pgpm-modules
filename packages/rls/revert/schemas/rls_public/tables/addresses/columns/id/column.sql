-- Revert: schemas/rls_public/tables/addresses/columns/id/column from pg

BEGIN;


ALTER TABLE "rls_public".addresses DROP COLUMN id;
COMMIT;  


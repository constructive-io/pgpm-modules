-- Revert: schemas/rls_public/tables/addresses/columns/state/column from pg

BEGIN;


ALTER TABLE "rls_public".addresses DROP COLUMN state;
COMMIT;  


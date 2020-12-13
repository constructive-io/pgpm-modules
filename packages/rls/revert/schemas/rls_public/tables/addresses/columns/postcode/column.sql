-- Revert: schemas/rls_public/tables/addresses/columns/postcode/column from pg

BEGIN;


ALTER TABLE "rls_public".addresses DROP COLUMN postcode;
COMMIT;  


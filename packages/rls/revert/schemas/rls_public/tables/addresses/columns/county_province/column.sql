-- Revert: schemas/rls_public/tables/addresses/columns/county_province/column from pg

BEGIN;


ALTER TABLE "rls_public".addresses DROP COLUMN county_province;
COMMIT;  


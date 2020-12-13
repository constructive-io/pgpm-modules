-- Revert: schemas/rls_public/tables/addresses/columns/city/column from pg

BEGIN;


ALTER TABLE "rls_public".addresses DROP COLUMN city;
COMMIT;  


-- Revert: schemas/rls_public/tables/addresses/columns/address_line_1/column from pg

BEGIN;


ALTER TABLE "rls_public".addresses DROP COLUMN address_line_1;
COMMIT;  


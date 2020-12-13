-- Revert: schemas/rls_public/tables/addresses/table from pg

BEGIN;
DROP TABLE "rls_public".addresses;
COMMIT;  


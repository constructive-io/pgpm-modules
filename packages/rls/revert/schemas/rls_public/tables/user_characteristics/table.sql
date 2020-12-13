-- Revert: schemas/rls_public/tables/user_characteristics/table from pg

BEGIN;
DROP TABLE "rls_public".user_characteristics;
COMMIT;  


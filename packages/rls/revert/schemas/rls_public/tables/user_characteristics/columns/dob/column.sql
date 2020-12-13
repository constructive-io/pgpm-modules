-- Revert: schemas/rls_public/tables/user_characteristics/columns/dob/column from pg

BEGIN;


ALTER TABLE "rls_public".user_characteristics DROP COLUMN dob;
COMMIT;  


-- Revert: schemas/rls_public/tables/user_characteristics/columns/gender/column from pg

BEGIN;


ALTER TABLE "rls_public".user_characteristics DROP COLUMN gender;
COMMIT;  


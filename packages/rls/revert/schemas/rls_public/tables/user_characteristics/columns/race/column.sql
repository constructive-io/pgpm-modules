-- Revert: schemas/rls_public/tables/user_characteristics/columns/race/column from pg

BEGIN;


ALTER TABLE "rls_public".user_characteristics DROP COLUMN race;
COMMIT;  


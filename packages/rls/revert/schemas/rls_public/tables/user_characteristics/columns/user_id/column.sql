-- Revert: schemas/rls_public/tables/user_characteristics/columns/user_id/column from pg

BEGIN;


ALTER TABLE "rls_public".user_characteristics DROP COLUMN user_id;
COMMIT;  


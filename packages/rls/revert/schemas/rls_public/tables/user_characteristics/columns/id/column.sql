-- Revert: schemas/rls_public/tables/user_characteristics/columns/id/column from pg

BEGIN;


ALTER TABLE "rls_public".user_characteristics DROP COLUMN id;
COMMIT;  


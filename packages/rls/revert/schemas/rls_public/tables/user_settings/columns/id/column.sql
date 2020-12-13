-- Revert: schemas/rls_public/tables/user_settings/columns/id/column from pg

BEGIN;


ALTER TABLE "rls_public".user_settings DROP COLUMN id;
COMMIT;  


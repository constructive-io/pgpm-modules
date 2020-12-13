-- Revert: schemas/rls_public/tables/user_settings/columns/last_name/column from pg

BEGIN;


ALTER TABLE "rls_public".user_settings DROP COLUMN last_name;
COMMIT;  


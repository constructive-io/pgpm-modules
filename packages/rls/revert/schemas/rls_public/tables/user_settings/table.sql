-- Revert: schemas/rls_public/tables/user_settings/table from pg

BEGIN;
DROP TABLE "rls_public".user_settings;
COMMIT;  


-- Revert: schemas/rls_public/tables/user_settings/columns/id/alterations/alt0000000098 from pg

BEGIN;


ALTER TABLE "rls_public".user_settings 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  


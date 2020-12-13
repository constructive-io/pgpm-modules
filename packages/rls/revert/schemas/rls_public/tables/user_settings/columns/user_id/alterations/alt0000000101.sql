-- Revert: schemas/rls_public/tables/user_settings/columns/user_id/alterations/alt0000000101 from pg

BEGIN;


ALTER TABLE "rls_public".user_settings 
    ALTER COLUMN user_id DROP NOT NULL;


COMMIT;  


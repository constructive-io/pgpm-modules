-- Revert: schemas/rls_public/tables/user_characteristics/columns/user_id/alterations/alt0000000107 from pg

BEGIN;


ALTER TABLE "rls_public".user_characteristics 
    ALTER COLUMN user_id DROP NOT NULL;


COMMIT;  


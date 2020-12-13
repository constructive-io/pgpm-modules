-- Revert: schemas/rls_public/tables/user_characteristics/columns/id/alterations/alt0000000106 from pg

BEGIN;


ALTER TABLE "rls_public".user_characteristics 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  


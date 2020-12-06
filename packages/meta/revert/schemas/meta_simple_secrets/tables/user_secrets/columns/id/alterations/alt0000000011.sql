-- Revert: schemas/meta_simple_secrets/tables/user_secrets/columns/id/alterations/alt0000000011 from pg

BEGIN;


ALTER TABLE "meta_simple_secrets".user_secrets 
    ALTER COLUMN id DROP NOT NULL;


COMMIT;  


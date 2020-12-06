-- Revert: schemas/meta_public/tables/emails/columns/is_verified/alterations/alt0000000040 from pg

BEGIN;


ALTER TABLE "meta_public".emails 
    ALTER COLUMN is_verified DROP NOT NULL;


COMMIT;  


-- Revert: schemas/meta_public/tables/emails/columns/email/alterations/alt0000000039 from pg

BEGIN;


ALTER TABLE "meta_public".emails 
    ALTER COLUMN email DROP NOT NULL;


COMMIT;  


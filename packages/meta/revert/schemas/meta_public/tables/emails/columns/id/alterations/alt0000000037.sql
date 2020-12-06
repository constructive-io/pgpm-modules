-- Revert: schemas/meta_public/tables/emails/columns/id/alterations/alt0000000037 from pg

BEGIN;


ALTER TABLE "meta_public".emails 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  


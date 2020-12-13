-- Revert: schemas/rls_public/tables/emails/columns/id/alterations/alt0000000039 from pg

BEGIN;


ALTER TABLE "rls_public".emails 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  


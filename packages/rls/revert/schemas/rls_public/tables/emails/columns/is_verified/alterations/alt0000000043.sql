-- Revert: schemas/rls_public/tables/emails/columns/is_verified/alterations/alt0000000043 from pg

BEGIN;


ALTER TABLE "rls_public".emails 
    ALTER COLUMN is_verified DROP DEFAULT;

COMMIT;  


-- Revert: schemas/rls_public/tables/emails/columns/email/alterations/alt0000000041 from pg

BEGIN;


ALTER TABLE "rls_public".emails 
    ALTER COLUMN email DROP NOT NULL;


COMMIT;  


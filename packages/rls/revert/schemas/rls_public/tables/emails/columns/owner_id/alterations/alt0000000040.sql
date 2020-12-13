-- Revert: schemas/rls_public/tables/emails/columns/owner_id/alterations/alt0000000040 from pg

BEGIN;


ALTER TABLE "rls_public".emails 
    ALTER COLUMN owner_id DROP NOT NULL;


COMMIT;  


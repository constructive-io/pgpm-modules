-- Revert: schemas/rls_public/tables/addresses/columns/owner_id/alterations/alt0000000088 from pg

BEGIN;


ALTER TABLE "rls_public".addresses 
    ALTER COLUMN owner_id DROP NOT NULL;


COMMIT;  


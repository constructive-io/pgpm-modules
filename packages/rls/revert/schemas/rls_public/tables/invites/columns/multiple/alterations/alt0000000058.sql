-- Revert: schemas/rls_public/tables/invites/columns/multiple/alterations/alt0000000058 from pg

BEGIN;


ALTER TABLE "rls_public".invites 
    ALTER COLUMN multiple DROP NOT NULL;


COMMIT;  


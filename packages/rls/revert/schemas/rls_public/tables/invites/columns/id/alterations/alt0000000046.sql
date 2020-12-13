-- Revert: schemas/rls_public/tables/invites/columns/id/alterations/alt0000000046 from pg

BEGIN;


ALTER TABLE "rls_public".invites 
    ALTER COLUMN id DROP NOT NULL;


COMMIT;  


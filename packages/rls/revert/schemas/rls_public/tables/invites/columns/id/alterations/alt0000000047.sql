-- Revert: schemas/rls_public/tables/invites/columns/id/alterations/alt0000000047 from pg

BEGIN;


ALTER TABLE "rls_public".invites 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  


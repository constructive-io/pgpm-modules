-- Revert: schemas/rls_public/tables/claimed_invites/columns/id/alterations/alt0000000065 from pg

BEGIN;


ALTER TABLE "rls_public".claimed_invites 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  


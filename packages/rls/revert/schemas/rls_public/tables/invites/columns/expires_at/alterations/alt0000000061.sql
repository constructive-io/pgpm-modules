-- Revert: schemas/rls_public/tables/invites/columns/expires_at/alterations/alt0000000061 from pg

BEGIN;


ALTER TABLE "rls_public".invites 
    ALTER COLUMN expires_at DROP DEFAULT;

COMMIT;  


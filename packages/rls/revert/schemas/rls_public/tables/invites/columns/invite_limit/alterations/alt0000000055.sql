-- Revert: schemas/rls_public/tables/invites/columns/invite_limit/alterations/alt0000000055 from pg

BEGIN;


ALTER TABLE "rls_public".invites 
    ALTER COLUMN invite_limit DROP DEFAULT;

COMMIT;  


-- Revert: schemas/rls_public/tables/invites/columns/invite_token/alterations/alt0000000050 from pg

BEGIN;


ALTER TABLE "rls_public".invites 
    ALTER COLUMN invite_token DROP NOT NULL;


COMMIT;  


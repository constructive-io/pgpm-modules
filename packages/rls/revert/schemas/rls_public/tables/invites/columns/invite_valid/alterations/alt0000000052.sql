-- Revert: schemas/rls_public/tables/invites/columns/invite_valid/alterations/alt0000000052 from pg

BEGIN;


ALTER TABLE "rls_public".invites 
    ALTER COLUMN invite_valid DROP NOT NULL;


COMMIT;  


-- Revert: schemas/rls_public/tables/claimed_invites/columns/sender_id/alterations/alt0000000066 from pg

BEGIN;


ALTER TABLE "rls_public".claimed_invites 
    ALTER COLUMN sender_id DROP NOT NULL;


COMMIT;  


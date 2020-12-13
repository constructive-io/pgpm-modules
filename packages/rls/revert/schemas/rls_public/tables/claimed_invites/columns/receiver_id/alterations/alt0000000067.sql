-- Revert: schemas/rls_public/tables/claimed_invites/columns/receiver_id/alterations/alt0000000067 from pg

BEGIN;


ALTER TABLE "rls_public".claimed_invites 
    ALTER COLUMN receiver_id DROP NOT NULL;


COMMIT;  


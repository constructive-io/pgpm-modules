-- Revert: schemas/rls_public/tables/claimed_invites/constraints/claimed_invites_sender_id_fkey from pg

BEGIN;


ALTER TABLE "rls_public".claimed_invites 
    DROP CONSTRAINT claimed_invites_sender_id_fkey;

COMMIT;  


-- Revert: schemas/rls_public/tables/invites/constraints/invites_sender_id_fkey from pg

BEGIN;


ALTER TABLE "rls_public".invites 
    DROP CONSTRAINT invites_sender_id_fkey;

COMMIT;  


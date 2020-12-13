-- Revert: schemas/rls_public/tables/invites/constraints/invites_email_sender_id_key from pg

BEGIN;


ALTER TABLE "rls_public".invites 
    DROP CONSTRAINT invites_email_sender_id_key;

COMMIT;  


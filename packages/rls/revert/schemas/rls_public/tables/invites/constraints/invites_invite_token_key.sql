-- Revert: schemas/rls_public/tables/invites/constraints/invites_invite_token_key from pg

BEGIN;


ALTER TABLE "rls_public".invites 
    DROP CONSTRAINT invites_invite_token_key;

COMMIT;  


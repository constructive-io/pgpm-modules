-- Revert: schemas/rls_public/tables/claimed_invites/indexes/claimed_invites_receiver_id_idx from pg

BEGIN;


DROP INDEX "rls_public".claimed_invites_receiver_id_idx;

COMMIT;  


-- Revert: schemas/rls_public/tables/invites/indexes/invites_sender_id_idx from pg

BEGIN;


DROP INDEX "rls_public".invites_sender_id_idx;

COMMIT;  


-- Revert: schemas/rls_public/tables/invites/indexes/invites_invite_valid_idx from pg

BEGIN;


DROP INDEX "rls_public".invites_invite_valid_idx;

COMMIT;  


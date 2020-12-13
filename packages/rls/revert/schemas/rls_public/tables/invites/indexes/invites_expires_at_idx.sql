-- Revert: schemas/rls_public/tables/invites/indexes/invites_expires_at_idx from pg

BEGIN;


DROP INDEX "rls_public".invites_expires_at_idx;

COMMIT;  


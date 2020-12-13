-- Revert: schemas/rls_public/tables/invites/columns/expires_at/column from pg

BEGIN;


ALTER TABLE "rls_public".invites DROP COLUMN expires_at;
COMMIT;  


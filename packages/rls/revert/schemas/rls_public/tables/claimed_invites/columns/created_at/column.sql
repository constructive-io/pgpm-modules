-- Revert: schemas/rls_public/tables/claimed_invites/columns/created_at/column from pg

BEGIN;


ALTER TABLE "rls_public".claimed_invites DROP COLUMN created_at;
COMMIT;  


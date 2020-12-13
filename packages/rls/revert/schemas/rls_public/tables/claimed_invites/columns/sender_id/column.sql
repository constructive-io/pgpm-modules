-- Revert: schemas/rls_public/tables/claimed_invites/columns/sender_id/column from pg

BEGIN;


ALTER TABLE "rls_public".claimed_invites DROP COLUMN sender_id;
COMMIT;  


-- Revert: schemas/rls_public/tables/invites/columns/sender_id/column from pg

BEGIN;


ALTER TABLE "rls_public".invites DROP COLUMN sender_id;
COMMIT;  


-- Revert: schemas/rls_public/tables/invites/columns/invite_count/column from pg

BEGIN;


ALTER TABLE "rls_public".invites DROP COLUMN invite_count;
COMMIT;  


-- Revert: schemas/rls_public/tables/invites/columns/invite_limit/column from pg

BEGIN;


ALTER TABLE "rls_public".invites DROP COLUMN invite_limit;
COMMIT;  


-- Revert: schemas/rls_public/tables/claimed_invites/columns/data/column from pg

BEGIN;


ALTER TABLE "rls_public".claimed_invites DROP COLUMN data;
COMMIT;  


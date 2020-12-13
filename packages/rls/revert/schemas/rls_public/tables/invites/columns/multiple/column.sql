-- Revert: schemas/rls_public/tables/invites/columns/multiple/column from pg

BEGIN;


ALTER TABLE "rls_public".invites DROP COLUMN multiple;
COMMIT;  


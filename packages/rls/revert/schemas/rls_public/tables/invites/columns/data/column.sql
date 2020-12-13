-- Revert: schemas/rls_public/tables/invites/columns/data/column from pg

BEGIN;


ALTER TABLE "rls_public".invites DROP COLUMN data;
COMMIT;  


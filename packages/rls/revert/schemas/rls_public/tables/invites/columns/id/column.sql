-- Revert: schemas/rls_public/tables/invites/columns/id/column from pg

BEGIN;


ALTER TABLE "rls_public".invites DROP COLUMN id;
COMMIT;  


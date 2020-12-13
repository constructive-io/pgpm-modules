-- Revert: schemas/rls_public/tables/invites/columns/created_at/column from pg

BEGIN;


ALTER TABLE "rls_public".invites DROP COLUMN created_at;
COMMIT;  


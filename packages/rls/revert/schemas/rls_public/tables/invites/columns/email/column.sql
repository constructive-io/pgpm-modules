-- Revert: schemas/rls_public/tables/invites/columns/email/column from pg

BEGIN;


ALTER TABLE "rls_public".invites DROP COLUMN email;
COMMIT;  


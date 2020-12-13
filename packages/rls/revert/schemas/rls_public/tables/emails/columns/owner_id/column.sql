-- Revert: schemas/rls_public/tables/emails/columns/owner_id/column from pg

BEGIN;


ALTER TABLE "rls_public".emails DROP COLUMN owner_id;
COMMIT;  


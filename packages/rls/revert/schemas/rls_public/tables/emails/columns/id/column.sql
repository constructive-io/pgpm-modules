-- Revert: schemas/rls_public/tables/emails/columns/id/column from pg

BEGIN;


ALTER TABLE "rls_public".emails DROP COLUMN id;
COMMIT;  


-- Revert: schemas/rls_public/tables/emails/columns/email/column from pg

BEGIN;


ALTER TABLE "rls_public".emails DROP COLUMN email;
COMMIT;  


-- Revert: schemas/rls_public/tables/emails/columns/is_verified/column from pg

BEGIN;


ALTER TABLE "rls_public".emails DROP COLUMN is_verified;
COMMIT;  


-- Revert: schemas/rls_public/tables/user_contacts/columns/id/column from pg

BEGIN;


ALTER TABLE "rls_public".user_contacts DROP COLUMN id;
COMMIT;  


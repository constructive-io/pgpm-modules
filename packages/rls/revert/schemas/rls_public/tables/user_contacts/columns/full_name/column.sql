-- Revert: schemas/rls_public/tables/user_contacts/columns/full_name/column from pg

BEGIN;


ALTER TABLE "rls_public".user_contacts DROP COLUMN full_name;
COMMIT;  


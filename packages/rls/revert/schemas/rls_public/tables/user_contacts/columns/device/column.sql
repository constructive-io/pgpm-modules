-- Revert: schemas/rls_public/tables/user_contacts/columns/device/column from pg

BEGIN;


ALTER TABLE "rls_public".user_contacts DROP COLUMN device;
COMMIT;  


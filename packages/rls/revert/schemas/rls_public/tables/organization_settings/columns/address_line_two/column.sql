-- Revert: schemas/rls_public/tables/organization_settings/columns/address_line_two/column from pg

BEGIN;


ALTER TABLE "rls_public".organization_settings DROP COLUMN address_line_two;
COMMIT;  


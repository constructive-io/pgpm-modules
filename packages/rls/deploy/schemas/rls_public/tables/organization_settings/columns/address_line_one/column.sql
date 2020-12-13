-- Deploy: schemas/rls_public/tables/organization_settings/columns/address_line_one/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/organization_settings/table

BEGIN;

ALTER TABLE "rls_public".organization_settings ADD COLUMN address_line_one text;
COMMIT;

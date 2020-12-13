-- Deploy: schemas/rls_public/tables/user_contacts/columns/user_id/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_contacts/table

BEGIN;

ALTER TABLE "rls_public".user_contacts ADD COLUMN user_id uuid;
COMMIT;

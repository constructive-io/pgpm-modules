-- Deploy: schemas/rls_public/tables/user_contacts/columns/user_id/alterations/alt0000000116 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_contacts/table
-- requires: schemas/rls_public/tables/user_contacts/columns/user_id/column

BEGIN;

ALTER TABLE "rls_public".user_contacts 
    ALTER COLUMN user_id SET NOT NULL;
COMMIT;

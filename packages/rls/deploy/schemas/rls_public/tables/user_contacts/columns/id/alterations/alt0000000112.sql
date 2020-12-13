-- Deploy: schemas/rls_public/tables/user_contacts/columns/id/alterations/alt0000000112 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_contacts/table
-- requires: schemas/rls_public/tables/user_contacts/columns/id/column

BEGIN;

ALTER TABLE "rls_public".user_contacts 
    ALTER COLUMN id SET DEFAULT "rls_private".uuid_generate_v4();
COMMIT;

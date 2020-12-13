-- Deploy: schemas/rls_public/tables/user_contacts/alterations/alt0000000110 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_contacts/table

BEGIN;

ALTER TABLE "rls_public".user_contacts
    DISABLE ROW LEVEL SECURITY;
COMMIT;

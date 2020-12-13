-- Deploy: schemas/rls_public/tables/user_contacts/grants/authenticated/delete to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_contacts/table

BEGIN;
GRANT DELETE ON TABLE "rls_public".user_contacts TO authenticated;
COMMIT;

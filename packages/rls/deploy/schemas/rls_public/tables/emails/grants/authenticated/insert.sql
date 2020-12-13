-- Deploy: schemas/rls_public/tables/emails/grants/authenticated/insert to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/emails/table

BEGIN;
GRANT INSERT ON TABLE "rls_public".emails TO authenticated;
COMMIT;

-- Deploy: schemas/rls_public/tables/invites/grants/authenticated/delete to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table

BEGIN;
GRANT DELETE ON TABLE "rls_public".invites TO authenticated;
COMMIT;

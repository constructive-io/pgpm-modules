-- Deploy: schemas/rls_public/tables/invites/grants/authenticated/update to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table

BEGIN;
GRANT UPDATE ( expires_at ) ON TABLE "rls_public".invites TO authenticated;
COMMIT;

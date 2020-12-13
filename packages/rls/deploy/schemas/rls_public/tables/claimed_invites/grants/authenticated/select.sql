-- Deploy: schemas/rls_public/tables/claimed_invites/grants/authenticated/select to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/claimed_invites/table

BEGIN;
GRANT SELECT ON TABLE "rls_public".claimed_invites TO authenticated;
COMMIT;

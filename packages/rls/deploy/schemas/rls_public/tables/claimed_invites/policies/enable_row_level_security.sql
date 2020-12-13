-- Deploy: schemas/rls_public/tables/claimed_invites/policies/enable_row_level_security to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/claimed_invites/table

BEGIN;

ALTER TABLE "rls_public".claimed_invites
    ENABLE ROW LEVEL SECURITY;
COMMIT;

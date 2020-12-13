-- Deploy: schemas/rls_public/tables/claimed_invites/columns/id/alterations/alt0000000065 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/claimed_invites/table
-- requires: schemas/rls_public/tables/claimed_invites/columns/id/column

BEGIN;

ALTER TABLE "rls_public".claimed_invites 
    ALTER COLUMN id SET DEFAULT "rls_private".uuid_generate_v4();
COMMIT;

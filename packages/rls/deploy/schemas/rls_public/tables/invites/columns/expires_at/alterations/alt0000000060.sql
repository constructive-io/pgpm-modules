-- Deploy: schemas/rls_public/tables/invites/columns/expires_at/alterations/alt0000000060 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table
-- requires: schemas/rls_public/tables/invites/columns/expires_at/column

BEGIN;

ALTER TABLE "rls_public".invites 
    ALTER COLUMN expires_at SET NOT NULL;
COMMIT;

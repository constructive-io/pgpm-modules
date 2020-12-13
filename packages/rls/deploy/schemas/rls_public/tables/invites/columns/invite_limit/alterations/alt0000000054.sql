-- Deploy: schemas/rls_public/tables/invites/columns/invite_limit/alterations/alt0000000054 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table
-- requires: schemas/rls_public/tables/invites/columns/invite_limit/column

BEGIN;

ALTER TABLE "rls_public".invites 
    ALTER COLUMN invite_limit SET NOT NULL;
COMMIT;

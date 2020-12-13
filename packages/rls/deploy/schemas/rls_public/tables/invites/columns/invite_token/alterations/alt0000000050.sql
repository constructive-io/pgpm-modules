-- Deploy: schemas/rls_public/tables/invites/columns/invite_token/alterations/alt0000000050 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table
-- requires: schemas/rls_public/tables/invites/columns/invite_token/column

BEGIN;

ALTER TABLE "rls_public".invites 
    ALTER COLUMN invite_token SET NOT NULL;
COMMIT;

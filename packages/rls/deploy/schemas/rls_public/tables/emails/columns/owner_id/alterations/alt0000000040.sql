-- Deploy: schemas/rls_public/tables/emails/columns/owner_id/alterations/alt0000000040 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/emails/table
-- requires: schemas/rls_public/tables/emails/columns/owner_id/column

BEGIN;

ALTER TABLE "rls_public".emails 
    ALTER COLUMN owner_id SET NOT NULL;
COMMIT;

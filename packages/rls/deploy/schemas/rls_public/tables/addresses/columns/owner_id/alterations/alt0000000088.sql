-- Deploy: schemas/rls_public/tables/addresses/columns/owner_id/alterations/alt0000000088 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/addresses/table
-- requires: schemas/rls_public/tables/addresses/columns/owner_id/column

BEGIN;

ALTER TABLE "rls_public".addresses 
    ALTER COLUMN owner_id SET NOT NULL;
COMMIT;

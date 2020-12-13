-- Deploy: schemas/rls_public/tables/addresses/columns/id/alterations/alt0000000078 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/addresses/table
-- requires: schemas/rls_public/tables/addresses/columns/id/column

BEGIN;

ALTER TABLE "rls_public".addresses 
    ALTER COLUMN id SET NOT NULL;
COMMIT;

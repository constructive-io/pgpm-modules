-- Deploy: schemas/meta_public/tables/domains/columns/owner_id/alterations/alt0000000080 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/domains/table
-- requires: schemas/meta_public/tables/domains/columns/owner_id/column

BEGIN;

ALTER TABLE "meta_public".domains 
    ALTER COLUMN owner_id SET NOT NULL;
COMMIT;

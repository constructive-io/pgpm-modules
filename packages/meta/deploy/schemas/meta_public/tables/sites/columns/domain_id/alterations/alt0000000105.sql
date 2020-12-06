-- Deploy: schemas/meta_public/tables/sites/columns/domain_id/alterations/alt0000000105 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/sites/table
-- requires: schemas/meta_public/tables/sites/columns/domain_id/column

BEGIN;

ALTER TABLE "meta_public".sites 
    ALTER COLUMN domain_id SET NOT NULL;
COMMIT;

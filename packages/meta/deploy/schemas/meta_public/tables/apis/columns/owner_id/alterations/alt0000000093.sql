-- Deploy: schemas/meta_public/tables/apis/columns/owner_id/alterations/alt0000000093 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/apis/table
-- requires: schemas/meta_public/tables/apis/columns/owner_id/column

BEGIN;

ALTER TABLE "meta_public".apis 
    ALTER COLUMN owner_id SET NOT NULL;
COMMIT;

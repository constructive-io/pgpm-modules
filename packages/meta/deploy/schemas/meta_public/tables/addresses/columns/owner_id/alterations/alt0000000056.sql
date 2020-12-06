-- Deploy: schemas/meta_public/tables/addresses/columns/owner_id/alterations/alt0000000056 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/addresses/table
-- requires: schemas/meta_public/tables/addresses/columns/owner_id/column

BEGIN;

ALTER TABLE "meta_public".addresses 
    ALTER COLUMN owner_id SET NOT NULL;
COMMIT;

-- Deploy: schemas/meta_private/tables/api_tokens/columns/id/alterations/alt0000000017 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_private/schema
-- requires: schemas/meta_private/tables/api_tokens/table
-- requires: schemas/meta_private/tables/api_tokens/columns/id/column

BEGIN;

ALTER TABLE "meta_private".api_tokens 
    ALTER COLUMN id SET NOT NULL;
COMMIT;

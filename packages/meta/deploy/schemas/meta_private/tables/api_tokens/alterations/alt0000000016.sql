-- Deploy: schemas/meta_private/tables/api_tokens/alterations/alt0000000016 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_private/schema
-- requires: schemas/meta_private/tables/api_tokens/table

BEGIN;

ALTER TABLE "meta_private".api_tokens
    DISABLE ROW LEVEL SECURITY;
COMMIT;

-- Deploy: schemas/meta_private/tables/api_tokens/columns/access_token_expires_at/alterations/alt0000000023 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_private/schema
-- requires: schemas/meta_private/tables/api_tokens/table
-- requires: schemas/meta_private/tables/api_tokens/columns/access_token_expires_at/column

BEGIN;

ALTER TABLE "meta_private".api_tokens 
    ALTER COLUMN access_token_expires_at SET DEFAULT (NOW() + interval '30 days');
COMMIT;

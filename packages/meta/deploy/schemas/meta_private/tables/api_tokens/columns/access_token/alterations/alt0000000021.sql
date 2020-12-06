-- Deploy: schemas/meta_private/tables/api_tokens/columns/access_token/alterations/alt0000000021 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_private/schema
-- requires: schemas/meta_private/tables/api_tokens/table
-- requires: schemas/meta_private/tables/api_tokens/columns/access_token/column

BEGIN;

ALTER TABLE "meta_private".api_tokens 
    ALTER COLUMN access_token SET DEFAULT encode( gen_random_bytes( 48 ), 'hex' );
COMMIT;

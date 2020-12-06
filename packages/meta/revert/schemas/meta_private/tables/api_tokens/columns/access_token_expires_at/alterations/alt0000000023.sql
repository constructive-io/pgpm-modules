-- Revert: schemas/meta_private/tables/api_tokens/columns/access_token_expires_at/alterations/alt0000000023 from pg

BEGIN;


ALTER TABLE "meta_private".api_tokens 
    ALTER COLUMN access_token_expires_at DROP DEFAULT;

COMMIT;  


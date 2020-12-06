-- Revert: schemas/meta_private/tables/api_tokens/columns/access_token/alterations/alt0000000020 from pg

BEGIN;


ALTER TABLE "meta_private".api_tokens 
    ALTER COLUMN access_token DROP NOT NULL;


COMMIT;  


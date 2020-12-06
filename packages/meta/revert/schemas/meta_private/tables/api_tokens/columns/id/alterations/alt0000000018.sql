-- Revert: schemas/meta_private/tables/api_tokens/columns/id/alterations/alt0000000018 from pg

BEGIN;


ALTER TABLE "meta_private".api_tokens 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  


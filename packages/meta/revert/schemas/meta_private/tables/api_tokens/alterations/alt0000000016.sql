-- Revert: schemas/meta_private/tables/api_tokens/alterations/alt0000000016 from pg

BEGIN;


ALTER TABLE "meta_private".api_tokens
    ENABLE ROW LEVEL SECURITY;

COMMIT;  


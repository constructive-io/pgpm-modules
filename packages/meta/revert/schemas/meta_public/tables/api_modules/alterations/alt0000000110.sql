-- Revert: schemas/meta_public/tables/api_modules/alterations/alt0000000110 from pg

BEGIN;


ALTER TABLE "meta_public".api_modules
    ENABLE ROW LEVEL SECURITY;

COMMIT;  


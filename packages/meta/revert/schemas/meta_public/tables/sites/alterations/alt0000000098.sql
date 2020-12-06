-- Revert: schemas/meta_public/tables/sites/alterations/alt0000000098 from pg

BEGIN;


ALTER TABLE "meta_public".sites
    ENABLE ROW LEVEL SECURITY;

COMMIT;  


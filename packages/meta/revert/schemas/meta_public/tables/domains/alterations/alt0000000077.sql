-- Revert: schemas/meta_public/tables/domains/alterations/alt0000000077 from pg

BEGIN;


ALTER TABLE "meta_public".domains
    ENABLE ROW LEVEL SECURITY;

COMMIT;  


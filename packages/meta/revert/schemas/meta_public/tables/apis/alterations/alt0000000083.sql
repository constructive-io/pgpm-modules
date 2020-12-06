-- Revert: schemas/meta_public/tables/apis/alterations/alt0000000083 from pg

BEGIN;


ALTER TABLE "meta_public".apis
    ENABLE ROW LEVEL SECURITY;

COMMIT;  


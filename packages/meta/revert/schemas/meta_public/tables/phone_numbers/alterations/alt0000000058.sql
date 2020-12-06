-- Revert: schemas/meta_public/tables/phone_numbers/alterations/alt0000000058 from pg

BEGIN;


ALTER TABLE "meta_public".phone_numbers
    ENABLE ROW LEVEL SECURITY;

COMMIT;  


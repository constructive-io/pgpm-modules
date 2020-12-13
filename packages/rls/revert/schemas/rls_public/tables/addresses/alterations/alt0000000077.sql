-- Revert: schemas/rls_public/tables/addresses/alterations/alt0000000077 from pg

BEGIN;


ALTER TABLE "rls_public".addresses
    ENABLE ROW LEVEL SECURITY;

COMMIT;  


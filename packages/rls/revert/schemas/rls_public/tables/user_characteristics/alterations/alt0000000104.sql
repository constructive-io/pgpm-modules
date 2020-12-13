-- Revert: schemas/rls_public/tables/user_characteristics/alterations/alt0000000104 from pg

BEGIN;


ALTER TABLE "rls_public".user_characteristics
    ENABLE ROW LEVEL SECURITY;

COMMIT;  


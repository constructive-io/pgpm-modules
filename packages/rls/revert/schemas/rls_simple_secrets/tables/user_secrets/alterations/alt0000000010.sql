-- Revert: schemas/rls_simple_secrets/tables/user_secrets/alterations/alt0000000010 from pg

BEGIN;


ALTER TABLE "rls_simple_secrets".user_secrets
    ENABLE ROW LEVEL SECURITY;

COMMIT;  


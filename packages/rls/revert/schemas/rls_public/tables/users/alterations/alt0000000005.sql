-- Revert: schemas/rls_public/tables/users/alterations/alt0000000005 from pg

BEGIN;


ALTER TABLE "rls_public".users
    ENABLE ROW LEVEL SECURITY;

COMMIT;  


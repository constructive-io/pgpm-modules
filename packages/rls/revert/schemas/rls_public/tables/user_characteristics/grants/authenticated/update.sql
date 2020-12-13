-- Revert: schemas/rls_public/tables/user_characteristics/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE "rls_public".user_characteristics FROM authenticated;
COMMIT;  


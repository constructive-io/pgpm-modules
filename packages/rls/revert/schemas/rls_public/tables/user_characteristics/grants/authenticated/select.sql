-- Revert: schemas/rls_public/tables/user_characteristics/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE "rls_public".user_characteristics FROM authenticated;
COMMIT;  


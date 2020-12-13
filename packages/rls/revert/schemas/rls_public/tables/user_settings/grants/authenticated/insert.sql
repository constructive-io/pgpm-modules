-- Revert: schemas/rls_public/tables/user_settings/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE "rls_public".user_settings FROM authenticated;
COMMIT;  


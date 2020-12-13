-- Revert: schemas/rls_public/tables/user_settings/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE "rls_public".user_settings FROM authenticated;
COMMIT;  


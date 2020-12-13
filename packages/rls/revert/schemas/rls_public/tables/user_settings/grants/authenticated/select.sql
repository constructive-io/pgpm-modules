-- Revert: schemas/rls_public/tables/user_settings/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE "rls_public".user_settings FROM authenticated;
COMMIT;  


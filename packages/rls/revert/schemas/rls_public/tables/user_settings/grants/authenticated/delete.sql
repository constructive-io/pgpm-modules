-- Revert: schemas/rls_public/tables/user_settings/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE "rls_public".user_settings FROM authenticated;
COMMIT;  


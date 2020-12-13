-- Revert: schemas/rls_public/tables/user_contacts/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE "rls_public".user_contacts FROM authenticated;
COMMIT;  


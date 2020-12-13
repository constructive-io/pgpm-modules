-- Revert: schemas/rls_public/tables/user_contacts/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE "rls_public".user_contacts FROM authenticated;
COMMIT;  


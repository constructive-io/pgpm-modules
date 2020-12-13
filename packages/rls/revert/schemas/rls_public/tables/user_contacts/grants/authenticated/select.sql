-- Revert: schemas/rls_public/tables/user_contacts/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE "rls_public".user_contacts FROM authenticated;
COMMIT;  


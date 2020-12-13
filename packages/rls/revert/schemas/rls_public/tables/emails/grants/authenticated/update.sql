-- Revert: schemas/rls_public/tables/emails/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE "rls_public".emails FROM authenticated;
COMMIT;  


-- Revert: schemas/rls_public/tables/emails/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE "rls_public".emails FROM authenticated;
COMMIT;  


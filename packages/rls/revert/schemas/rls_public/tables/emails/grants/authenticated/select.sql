-- Revert: schemas/rls_public/tables/emails/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE "rls_public".emails FROM authenticated;
COMMIT;  


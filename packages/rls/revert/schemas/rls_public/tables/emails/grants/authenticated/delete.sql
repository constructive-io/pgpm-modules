-- Revert: schemas/rls_public/tables/emails/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE "rls_public".emails FROM authenticated;
COMMIT;  


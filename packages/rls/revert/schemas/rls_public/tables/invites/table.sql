-- Revert: schemas/rls_public/tables/invites/table from pg

BEGIN;
DROP TABLE "rls_public".invites;
COMMIT;  


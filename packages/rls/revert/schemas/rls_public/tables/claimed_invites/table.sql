-- Revert: schemas/rls_public/tables/claimed_invites/table from pg

BEGIN;
DROP TABLE "rls_public".claimed_invites;
COMMIT;  


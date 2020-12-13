-- Revert: schemas/rls_public/tables/invites/columns/created_at/alterations/alt0000000063 from pg

BEGIN;


ALTER TABLE "rls_public".invites 
    ALTER COLUMN created_at DROP DEFAULT;

COMMIT;  


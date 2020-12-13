-- Revert: schemas/rls_public/tables/addresses/columns/owner_id/column from pg

BEGIN;


ALTER TABLE "rls_public".addresses DROP COLUMN owner_id;
COMMIT;  


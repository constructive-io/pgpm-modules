-- Revert: schemas/meta_public/tables/emails/columns/owner_id/column from pg

BEGIN;


ALTER TABLE "meta_public".emails DROP COLUMN owner_id;
COMMIT;  


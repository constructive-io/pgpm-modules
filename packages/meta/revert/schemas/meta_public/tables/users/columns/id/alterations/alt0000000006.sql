-- Revert: schemas/meta_public/tables/users/columns/id/alterations/alt0000000006 from pg

BEGIN;


ALTER TABLE "meta_public".users 
    ALTER COLUMN id DROP NOT NULL;


COMMIT;  


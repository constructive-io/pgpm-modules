-- Revert: schemas/rls_public/tables/addresses/triggers/tg_peoplestamps from pg

BEGIN;


ALTER TABLE "rls_public".addresses DROP COLUMN created_by;
ALTER TABLE "rls_public".addresses DROP COLUMN updated_by;

DROP TRIGGER tg_peoplestamps
ON "rls_public".addresses;


COMMIT;  


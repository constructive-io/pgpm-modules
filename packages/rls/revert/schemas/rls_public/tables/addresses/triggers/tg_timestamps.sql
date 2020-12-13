-- Revert: schemas/rls_public/tables/addresses/triggers/tg_timestamps from pg

BEGIN;


ALTER TABLE "rls_public".addresses DROP COLUMN created_at;
ALTER TABLE "rls_public".addresses DROP COLUMN updated_at;

DROP TRIGGER tg_timestamps ON "rls_public".addresses;

COMMIT;  


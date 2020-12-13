-- Revert: schemas/rls_public/tables/user_characteristics/triggers/tg_timestamps from pg

BEGIN;


ALTER TABLE "rls_public".user_characteristics DROP COLUMN created_at;
ALTER TABLE "rls_public".user_characteristics DROP COLUMN updated_at;

DROP TRIGGER tg_timestamps ON "rls_public".user_characteristics;

COMMIT;  


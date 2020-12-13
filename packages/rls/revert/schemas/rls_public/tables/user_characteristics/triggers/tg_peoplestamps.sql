-- Revert: schemas/rls_public/tables/user_characteristics/triggers/tg_peoplestamps from pg

BEGIN;


ALTER TABLE "rls_public".user_characteristics DROP COLUMN created_by;
ALTER TABLE "rls_public".user_characteristics DROP COLUMN updated_by;

DROP TRIGGER tg_peoplestamps
ON "rls_public".user_characteristics;


COMMIT;  


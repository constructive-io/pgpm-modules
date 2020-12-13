-- Revert: schemas/rls_public/tables/user_connections/triggers/tg_peoplestamps from pg

BEGIN;


ALTER TABLE "rls_public".user_connections DROP COLUMN created_by;
ALTER TABLE "rls_public".user_connections DROP COLUMN updated_by;

DROP TRIGGER tg_peoplestamps
ON "rls_public".user_connections;


COMMIT;  


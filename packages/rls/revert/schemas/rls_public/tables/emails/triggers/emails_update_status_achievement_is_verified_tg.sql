-- Revert: schemas/rls_public/tables/emails/triggers/emails_update_status_achievement_is_verified_tg from pg

BEGIN;
DROP TRIGGER emails_update_status_achievement_is_verified_tg ON "rls_public".emails;
COMMIT;  


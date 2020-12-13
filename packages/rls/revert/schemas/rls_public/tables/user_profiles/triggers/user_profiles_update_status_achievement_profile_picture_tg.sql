-- Revert: schemas/rls_public/tables/user_profiles/triggers/user_profiles_update_status_achievement_profile_picture_tg from pg

BEGIN;
DROP TRIGGER user_profiles_update_status_achievement_profile_picture_tg ON "rls_public".user_profiles;
COMMIT;  


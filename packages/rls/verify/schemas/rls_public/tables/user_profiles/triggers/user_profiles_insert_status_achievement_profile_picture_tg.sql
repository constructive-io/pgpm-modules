-- Verify: schemas/rls_public/tables/user_profiles/triggers/user_profiles_insert_status_achievement_profile_picture_tg on pg

BEGIN;
SELECT verify_trigger('rls_public.user_profiles_insert_status_achievement_profile_picture_tg');
COMMIT;  


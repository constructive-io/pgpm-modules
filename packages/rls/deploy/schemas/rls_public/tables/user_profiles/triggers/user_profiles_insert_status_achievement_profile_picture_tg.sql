-- Deploy: schemas/rls_public/tables/user_profiles/triggers/user_profiles_insert_status_achievement_profile_picture_tg to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_private/schema
-- requires: schemas/rls_public/tables/user_profiles/table
-- requires: schemas/rls_private/trigger_fns/tg_achievement_toggle

BEGIN;
CREATE TRIGGER user_profiles_insert_status_achievement_profile_picture_tg 
 BEFORE INSERT ON "rls_public".user_profiles 
 FOR EACH ROW 
 EXECUTE PROCEDURE "rls_private".tg_achievement_toggle ( 'profile_picture', 'upload_profile_picture' );
COMMIT;

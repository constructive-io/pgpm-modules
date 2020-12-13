-- Deploy: schemas/rls_public/tables/emails/triggers/emails_insert_status_achievement_is_verified_tg to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_private/schema
-- requires: schemas/rls_public/tables/emails/table
-- requires: schemas/rls_private/trigger_fns/tg_achievement_boolean

BEGIN;
CREATE TRIGGER emails_insert_status_achievement_is_verified_tg 
 BEFORE INSERT ON "rls_public".emails 
 FOR EACH ROW 
 EXECUTE PROCEDURE "rls_private".tg_achievement_boolean ( 'is_verified', 'email_verified' );
COMMIT;

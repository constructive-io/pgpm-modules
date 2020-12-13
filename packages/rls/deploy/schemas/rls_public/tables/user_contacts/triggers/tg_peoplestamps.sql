-- Deploy: schemas/rls_public/tables/user_contacts/triggers/tg_peoplestamps to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_contacts/table
-- requires: schemas/rls_private/trigger_fns/tg_peoplestamps

BEGIN;

ALTER TABLE "rls_public".user_contacts ADD COLUMN created_by UUID;
ALTER TABLE "rls_public".user_contacts ADD COLUMN updated_by UUID;
CREATE TRIGGER tg_peoplestamps
BEFORE UPDATE OR INSERT ON "rls_public".user_contacts
FOR EACH ROW
EXECUTE PROCEDURE "rls_private".tg_peoplestamps();
COMMIT;

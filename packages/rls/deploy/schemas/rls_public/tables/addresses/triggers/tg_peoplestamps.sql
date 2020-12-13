-- Deploy: schemas/rls_public/tables/addresses/triggers/tg_peoplestamps to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/addresses/table
-- requires: schemas/rls_private/trigger_fns/tg_peoplestamps

BEGIN;

ALTER TABLE "rls_public".addresses ADD COLUMN created_by UUID;
ALTER TABLE "rls_public".addresses ADD COLUMN updated_by UUID;
CREATE TRIGGER tg_peoplestamps
BEFORE UPDATE OR INSERT ON "rls_public".addresses
FOR EACH ROW
EXECUTE PROCEDURE "rls_private".tg_peoplestamps();
COMMIT;

-- Deploy: schemas/rls_public/tables/user_contacts/alterations/alt0000000113 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_contacts/table

BEGIN;
ALTER TABLE "rls_public".user_contacts ADD CONSTRAINT user_contacts_full_name_chk CHECK (character_length(full_name) <= 120);
COMMIT;

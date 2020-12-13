-- Deploy: schemas/rls_public/tables/user_contacts/indexes/user_contacts_user_id_idx to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_contacts/table

BEGIN;

CREATE INDEX user_contacts_user_id_idx ON "rls_public".user_contacts (user_id);
COMMIT;

-- Deploy: schemas/rls_public/tables/user_contacts/constraints/user_contacts_pkey to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_contacts/table

BEGIN;

ALTER TABLE "rls_public".user_contacts
    ADD CONSTRAINT user_contacts_pkey PRIMARY KEY (id);
COMMIT;

-- Deploy: schemas/rls_public/tables/user_contacts/constraints/user_contacts_user_id_fkey to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/users/table
-- requires: schemas/rls_public/tables/user_contacts/table
-- requires: schemas/rls_public/tables/users/columns/id/column
-- requires: schemas/rls_public/tables/user_contacts/columns/user_id/column

BEGIN;

ALTER TABLE "rls_public".user_contacts 
    ADD CONSTRAINT user_contacts_user_id_fkey 
    FOREIGN KEY (user_id)
    REFERENCES "rls_public".users (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
COMMIT;

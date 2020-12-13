-- Deploy: schemas/rls_public/tables/emails/constraints/emails_owner_id_fkey to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/users/table
-- requires: schemas/rls_public/tables/emails/table
-- requires: schemas/rls_public/tables/users/columns/id/column
-- requires: schemas/rls_public/tables/emails/columns/owner_id/column

BEGIN;

ALTER TABLE "rls_public".emails 
    ADD CONSTRAINT emails_owner_id_fkey 
    FOREIGN KEY (owner_id)
    REFERENCES "rls_public".users (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
COMMIT;

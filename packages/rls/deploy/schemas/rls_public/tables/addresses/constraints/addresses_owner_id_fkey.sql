-- Deploy: schemas/rls_public/tables/addresses/constraints/addresses_owner_id_fkey to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/users/table
-- requires: schemas/rls_public/tables/addresses/table
-- requires: schemas/rls_public/tables/users/columns/id/column
-- requires: schemas/rls_public/tables/addresses/columns/owner_id/column

BEGIN;

ALTER TABLE "rls_public".addresses 
    ADD CONSTRAINT addresses_owner_id_fkey 
    FOREIGN KEY (owner_id)
    REFERENCES "rls_public".users (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
COMMIT;

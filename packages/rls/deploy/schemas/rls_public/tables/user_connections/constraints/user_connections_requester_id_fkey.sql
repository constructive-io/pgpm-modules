-- Deploy: schemas/rls_public/tables/user_connections/constraints/user_connections_requester_id_fkey to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/users/table
-- requires: schemas/rls_public/tables/user_connections/table
-- requires: schemas/rls_public/tables/users/columns/id/column
-- requires: schemas/rls_public/tables/user_connections/columns/requester_id/column

BEGIN;

ALTER TABLE "rls_public".user_connections 
    ADD CONSTRAINT user_connections_requester_id_fkey 
    FOREIGN KEY (requester_id)
    REFERENCES "rls_public".users (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
COMMIT;

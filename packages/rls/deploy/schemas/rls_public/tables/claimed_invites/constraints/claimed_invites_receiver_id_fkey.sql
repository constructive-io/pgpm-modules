-- Deploy: schemas/rls_public/tables/claimed_invites/constraints/claimed_invites_receiver_id_fkey to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/users/table
-- requires: schemas/rls_public/tables/claimed_invites/table
-- requires: schemas/rls_public/tables/users/columns/id/column
-- requires: schemas/rls_public/tables/claimed_invites/columns/receiver_id/column

BEGIN;

ALTER TABLE "rls_public".claimed_invites 
    ADD CONSTRAINT claimed_invites_receiver_id_fkey 
    FOREIGN KEY (receiver_id)
    REFERENCES "rls_public".users (id)
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
COMMIT;

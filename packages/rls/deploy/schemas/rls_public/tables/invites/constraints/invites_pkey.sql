-- Deploy: schemas/rls_public/tables/invites/constraints/invites_pkey to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table

BEGIN;

ALTER TABLE "rls_public".invites
    ADD CONSTRAINT invites_pkey PRIMARY KEY (id);
COMMIT;

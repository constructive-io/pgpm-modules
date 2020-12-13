-- Deploy: schemas/rls_public/tables/claimed_invites/constraints/claimed_invites_pkey to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/claimed_invites/table

BEGIN;

ALTER TABLE "rls_public".claimed_invites
    ADD CONSTRAINT claimed_invites_pkey PRIMARY KEY (id);
COMMIT;

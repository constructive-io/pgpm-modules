-- Deploy: schemas/rls_public/tables/users/constraints/users_pkey to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/users/table

BEGIN;

ALTER TABLE "rls_public".users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);
COMMIT;

-- Deploy: schemas/rls_public/tables/addresses/constraints/addresses_pkey to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/addresses/table

BEGIN;

ALTER TABLE "rls_public".addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);
COMMIT;

-- Deploy: schemas/meta_public/alterations/alt0000000057 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT addresses_owner_id_fkey ON "meta_public".addresses IS E'@omit manyToMany';
COMMIT;

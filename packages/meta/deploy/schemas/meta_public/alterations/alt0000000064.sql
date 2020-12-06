-- Deploy: schemas/meta_public/alterations/alt0000000064 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT phone_numbers_owner_id_fkey ON "meta_public".phone_numbers IS E'@omit manyToMany';
COMMIT;

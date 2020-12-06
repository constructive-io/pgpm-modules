-- Deploy: schemas/meta_public/alterations/alt0000000094 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT apis_owner_id_fkey ON "meta_public".apis IS E'@omit manyToMany';
COMMIT;

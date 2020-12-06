-- Deploy: schemas/meta_public/alterations/alt0000000081 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT domains_owner_id_fkey ON "meta_public".domains IS E'@omit manyToMany';
COMMIT;

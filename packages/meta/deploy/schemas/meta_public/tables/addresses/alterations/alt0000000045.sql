-- Deploy: schemas/meta_public/tables/addresses/alterations/alt0000000045 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/addresses/table

BEGIN;

ALTER TABLE "meta_public".addresses
    DISABLE ROW LEVEL SECURITY;
COMMIT;

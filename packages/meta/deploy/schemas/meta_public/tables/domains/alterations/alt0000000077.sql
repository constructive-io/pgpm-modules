-- Deploy: schemas/meta_public/tables/domains/alterations/alt0000000077 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/domains/table

BEGIN;

ALTER TABLE "meta_public".domains
    DISABLE ROW LEVEL SECURITY;
COMMIT;

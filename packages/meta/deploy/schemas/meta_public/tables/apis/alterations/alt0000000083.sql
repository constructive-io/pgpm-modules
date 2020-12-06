-- Deploy: schemas/meta_public/tables/apis/alterations/alt0000000083 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/apis/table

BEGIN;

ALTER TABLE "meta_public".apis
    DISABLE ROW LEVEL SECURITY;
COMMIT;

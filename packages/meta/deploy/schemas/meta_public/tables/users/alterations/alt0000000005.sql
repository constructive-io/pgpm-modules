-- Deploy: schemas/meta_public/tables/users/alterations/alt0000000005 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/users/table

BEGIN;

ALTER TABLE "meta_public".users
    DISABLE ROW LEVEL SECURITY;
COMMIT;

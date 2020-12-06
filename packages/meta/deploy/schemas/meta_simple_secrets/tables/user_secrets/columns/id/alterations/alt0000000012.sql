-- Deploy: schemas/meta_simple_secrets/tables/user_secrets/columns/id/alterations/alt0000000012 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_simple_secrets/schema
-- requires: schemas/meta_simple_secrets/tables/user_secrets/table
-- requires: schemas/meta_simple_secrets/tables/user_secrets/columns/id/column

BEGIN;

ALTER TABLE "meta_simple_secrets".user_secrets 
    ALTER COLUMN id SET DEFAULT "meta_private".uuid_generate_v4();
COMMIT;

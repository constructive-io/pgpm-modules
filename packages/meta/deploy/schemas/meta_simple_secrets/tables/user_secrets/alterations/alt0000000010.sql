-- Deploy: schemas/meta_simple_secrets/tables/user_secrets/alterations/alt0000000010 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_simple_secrets/schema
-- requires: schemas/meta_simple_secrets/tables/user_secrets/table

BEGIN;

ALTER TABLE "meta_simple_secrets".user_secrets
    DISABLE ROW LEVEL SECURITY;
COMMIT;

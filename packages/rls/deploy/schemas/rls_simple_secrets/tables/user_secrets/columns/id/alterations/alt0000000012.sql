-- Deploy: schemas/rls_simple_secrets/tables/user_secrets/columns/id/alterations/alt0000000012 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_simple_secrets/schema
-- requires: schemas/rls_simple_secrets/tables/user_secrets/table
-- requires: schemas/rls_simple_secrets/tables/user_secrets/columns/id/column

BEGIN;

ALTER TABLE "rls_simple_secrets".user_secrets 
    ALTER COLUMN id SET DEFAULT "rls_private".uuid_generate_v4();
COMMIT;

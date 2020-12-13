-- Deploy: schemas/rls_simple_secrets/tables/user_secrets/alterations/alt0000000010 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_simple_secrets/schema
-- requires: schemas/rls_simple_secrets/tables/user_secrets/table

BEGIN;

ALTER TABLE "rls_simple_secrets".user_secrets
    DISABLE ROW LEVEL SECURITY;
COMMIT;

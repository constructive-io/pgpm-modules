-- Deploy: schemas/rls_roles_private/tables/api_tokens/alterations/alt0000000016 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_private/schema
-- requires: schemas/rls_roles_private/tables/api_tokens/table

BEGIN;

ALTER TABLE "rls_roles_private".api_tokens
    DISABLE ROW LEVEL SECURITY;
COMMIT;

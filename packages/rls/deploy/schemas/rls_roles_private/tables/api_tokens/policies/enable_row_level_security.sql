-- Deploy: schemas/rls_roles_private/tables/api_tokens/policies/enable_row_level_security to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_private/schema
-- requires: schemas/rls_roles_private/tables/api_tokens/table

BEGIN;

ALTER TABLE "rls_roles_private".api_tokens
    ENABLE ROW LEVEL SECURITY;
COMMIT;

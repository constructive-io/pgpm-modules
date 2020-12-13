-- Deploy: schemas/rls_roles_private/tables/api_tokens/columns/user_id/alterations/alt0000000019 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_private/schema
-- requires: schemas/rls_roles_private/tables/api_tokens/table
-- requires: schemas/rls_roles_private/tables/api_tokens/columns/user_id/column

BEGIN;

ALTER TABLE "rls_roles_private".api_tokens 
    ALTER COLUMN user_id SET NOT NULL;
COMMIT;

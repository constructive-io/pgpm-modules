-- Deploy: schemas/rls_roles_private/tables/api_tokens/columns/id/alterations/alt0000000017 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_private/schema
-- requires: schemas/rls_roles_private/tables/api_tokens/table
-- requires: schemas/rls_roles_private/tables/api_tokens/columns/id/column

BEGIN;

ALTER TABLE "rls_roles_private".api_tokens 
    ALTER COLUMN id SET NOT NULL;
COMMIT;

-- Deploy: schemas/rls_roles_private/tables/api_tokens/columns/access_token_expires_at/alterations/alt0000000022 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_private/schema
-- requires: schemas/rls_roles_private/tables/api_tokens/table
-- requires: schemas/rls_roles_private/tables/api_tokens/columns/access_token_expires_at/column

BEGIN;

ALTER TABLE "rls_roles_private".api_tokens 
    ALTER COLUMN access_token_expires_at SET NOT NULL;
COMMIT;

-- Deploy: schemas/rls_roles_private/tables/api_tokens/columns/id/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_private/schema
-- requires: schemas/rls_roles_private/tables/api_tokens/table

BEGIN;

ALTER TABLE "rls_roles_private".api_tokens ADD COLUMN id uuid;
COMMIT;

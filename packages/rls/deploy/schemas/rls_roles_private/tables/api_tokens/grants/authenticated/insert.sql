-- Deploy: schemas/rls_roles_private/tables/api_tokens/grants/authenticated/insert to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_private/schema
-- requires: schemas/rls_roles_private/tables/api_tokens/table

BEGIN;
GRANT INSERT ON TABLE "rls_roles_private".api_tokens TO authenticated;
COMMIT;

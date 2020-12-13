-- Deploy: schemas/rls_roles_private/tables/api_tokens/indexes/api_tokens_user_id_idx to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_private/schema
-- requires: schemas/rls_roles_private/tables/api_tokens/table

BEGIN;

CREATE INDEX api_tokens_user_id_idx ON "rls_roles_private".api_tokens (user_id);
COMMIT;

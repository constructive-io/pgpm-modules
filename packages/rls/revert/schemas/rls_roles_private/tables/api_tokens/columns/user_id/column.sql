-- Revert: schemas/rls_roles_private/tables/api_tokens/columns/user_id/column from pg

BEGIN;


ALTER TABLE "rls_roles_private".api_tokens DROP COLUMN user_id;
COMMIT;  


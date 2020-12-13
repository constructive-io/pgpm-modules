-- Revert: schemas/rls_roles_private/tables/api_tokens/columns/id/column from pg

BEGIN;


ALTER TABLE "rls_roles_private".api_tokens DROP COLUMN id;
COMMIT;  


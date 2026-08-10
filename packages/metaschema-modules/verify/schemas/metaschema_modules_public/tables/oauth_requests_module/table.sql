-- Verify schemas/metaschema_modules_public/tables/oauth_requests_module/table on pg

BEGIN;

SELECT id, database_id, scope
FROM metaschema_modules_public.oauth_requests_module
WHERE false;

ROLLBACK;

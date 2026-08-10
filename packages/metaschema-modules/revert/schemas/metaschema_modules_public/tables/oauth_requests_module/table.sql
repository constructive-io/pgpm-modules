-- Revert schemas/metaschema_modules_public/tables/oauth_requests_module/table from pg

BEGIN;

DROP TABLE metaschema_modules_public.oauth_requests_module;

COMMIT;

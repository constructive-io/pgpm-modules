-- Verify schemas/metaschema_modules_public/tables/agent_module/table on pg

BEGIN;

SELECT verify_table ('metaschema_modules_public.agent_module');

ROLLBACK;

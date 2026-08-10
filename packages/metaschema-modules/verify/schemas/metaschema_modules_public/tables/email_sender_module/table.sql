-- Verify schemas/metaschema_modules_public/tables/email_sender_module/table on pg

BEGIN;

SELECT id, database_id, scope
FROM metaschema_modules_public.email_sender_module
WHERE false;

ROLLBACK;

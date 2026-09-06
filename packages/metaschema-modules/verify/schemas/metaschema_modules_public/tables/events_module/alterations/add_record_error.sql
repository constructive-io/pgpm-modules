-- Verify schemas/metaschema_modules_public/tables/events_module/alterations/add_record_error on pg

BEGIN;

SELECT record_error FROM metaschema_modules_public.events_module WHERE FALSE;

ROLLBACK;

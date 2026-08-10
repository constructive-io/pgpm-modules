-- Revert schemas/metaschema_modules_public/tables/email_sender_module/table from pg

BEGIN;

DROP TABLE metaschema_modules_public.email_sender_module;

COMMIT;

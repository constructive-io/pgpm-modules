-- Revert schemas/metaschema_modules_public/tables/certificate_module/table from pg

BEGIN;

DROP TABLE IF EXISTS metaschema_modules_public.certificate_module;

COMMIT;

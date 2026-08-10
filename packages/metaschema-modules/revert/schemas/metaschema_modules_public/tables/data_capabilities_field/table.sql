-- Revert schemas/metaschema_modules_public/tables/data_capabilities_field/table from pg

BEGIN;

DROP TABLE metaschema_modules_public.data_capabilities_field;

COMMIT;

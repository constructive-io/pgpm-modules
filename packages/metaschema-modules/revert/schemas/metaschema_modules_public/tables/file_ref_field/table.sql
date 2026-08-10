-- Revert schemas/metaschema_modules_public/tables/file_ref_field/table from pg

BEGIN;

DROP TABLE metaschema_modules_public.file_ref_field;

COMMIT;

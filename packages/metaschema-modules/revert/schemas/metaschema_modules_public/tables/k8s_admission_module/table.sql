-- Revert schemas/metaschema_modules_public/tables/k8s_admission_module/table from pg

BEGIN;

DROP TABLE IF EXISTS metaschema_modules_public.k8s_admission_module CASCADE;

COMMIT;

-- Revert schemas/metaschema_modules_public/tables/cluster_module/table from pg

BEGIN;

DROP TABLE metaschema_modules_public.cluster_module;

COMMIT;

-- Revert schemas/metaschema_modules_public/tables/user_profiles_module/table from pg

BEGIN;

DROP TABLE IF EXISTS metaschema_modules_public.user_profiles_module;

COMMIT;

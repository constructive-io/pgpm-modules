-- Revert schemas/metaschema_modules_public/tables/refusal_log_module/constraints/one_platform_scope from pg

BEGIN;

DROP INDEX metaschema_modules_public.refusal_log_module_one_platform_scope;

COMMIT;

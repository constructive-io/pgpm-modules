-- Revert schemas/metaschema_modules_public/tables/billing_provider_module/alterations/add_has_due_reconciliations_function from pg

BEGIN;

ALTER TABLE metaschema_modules_public.billing_provider_module
  DROP COLUMN IF EXISTS has_due_reconciliations_function;

COMMIT;

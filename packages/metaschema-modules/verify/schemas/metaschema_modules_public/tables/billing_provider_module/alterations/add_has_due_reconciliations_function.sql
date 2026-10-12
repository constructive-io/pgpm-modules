-- Verify schemas/metaschema_modules_public/tables/billing_provider_module/alterations/add_has_due_reconciliations_function on pg

BEGIN;

SELECT has_due_reconciliations_function FROM metaschema_modules_public.billing_provider_module WHERE FALSE;

ROLLBACK;

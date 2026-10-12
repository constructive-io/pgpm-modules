-- Deploy schemas/metaschema_modules_public/tables/billing_provider_module/alterations/add_has_due_reconciliations_function to pg

-- requires: schemas/metaschema_modules_public/tables/billing_provider_module/table

BEGIN;

-- Output: the read-only sibling of list_due_reconciliations_function — answers
-- whether anything is due without stamping the watermark.
ALTER TABLE metaschema_modules_public.billing_provider_module
  ADD COLUMN IF NOT EXISTS has_due_reconciliations_function text NOT NULL DEFAULT '';

COMMIT;

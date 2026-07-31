-- Revert schemas/infra_utils/procedures/param_quantity from pg

BEGIN;

DROP FUNCTION IF EXISTS infra_utils.quantity_to_numeric(text);

COMMIT;

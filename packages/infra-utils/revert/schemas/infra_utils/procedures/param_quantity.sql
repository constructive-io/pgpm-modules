-- Revert schemas/infra_utils/procedures/param_quantity from pg

BEGIN;

DROP FUNCTION infra_utils.quantity_to_numeric(text);

COMMIT;

-- Verify schemas/infra_utils/procedures/param_quantity on pg

BEGIN;

SELECT verify_function('infra_utils.quantity_to_numeric');

ROLLBACK;

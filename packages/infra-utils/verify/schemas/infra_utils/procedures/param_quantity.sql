-- Verify schemas/infra_utils/procedures/param_quantity on pg

BEGIN;

SELECT assert_function('infra_utils.quantity_to_numeric(text)'::regprocedure);

ROLLBACK;

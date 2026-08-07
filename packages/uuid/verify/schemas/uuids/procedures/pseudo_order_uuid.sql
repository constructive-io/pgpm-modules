-- Verify schemas/uuids/procedures/pseudo_order_uuid  on pg

BEGIN;

SELECT assert_function('uuids.pseudo_order_uuid()'::regprocedure);

ROLLBACK;

-- Verify schemas/uuids/procedures/pseudo_order_seed_uuid  on pg

BEGIN;

SELECT assert_function('uuids.pseudo_order_seed_uuid(text)'::regprocedure);

ROLLBACK;

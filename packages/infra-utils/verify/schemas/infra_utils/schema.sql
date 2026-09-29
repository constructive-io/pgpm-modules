-- Verify schemas/infra_utils/schema  on pg

BEGIN;

SELECT assert_schema('infra_utils'::regnamespace);

ROLLBACK;

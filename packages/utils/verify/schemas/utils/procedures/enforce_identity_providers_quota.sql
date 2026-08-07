-- Verify schemas/utils/procedures/enforce_identity_providers_quota  on pg

BEGIN;

SELECT assert_function('utils.enforce_identity_providers_quota()'::regprocedure);

ROLLBACK;

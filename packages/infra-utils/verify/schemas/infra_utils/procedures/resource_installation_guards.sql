-- Verify schemas/infra_utils/procedures/resource_installation_guards on pg

BEGIN;

SELECT assert_function('infra_utils.assert_bundle_installable(uuid, text)'::regprocedure);
SELECT assert_function('infra_utils.assert_bundle_installed(uuid, uuid)'::regprocedure);

ROLLBACK;

-- Verify schemas/infra_utils/procedures/resource_installation_guards on pg

BEGIN;

SELECT verify_function('infra_utils.assert_bundle_installable');
SELECT verify_function('infra_utils.assert_bundle_installed');

ROLLBACK;

-- Revert schemas/infra_utils/procedures/resource_installation_guards from pg

BEGIN;

DROP FUNCTION IF EXISTS infra_utils.assert_bundle_installed(uuid, uuid);
DROP FUNCTION IF EXISTS infra_utils.assert_bundle_installable(uuid, text);

COMMIT;

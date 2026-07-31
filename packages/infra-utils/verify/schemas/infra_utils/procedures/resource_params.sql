-- Verify schemas/infra_utils/procedures/resource_params on pg

BEGIN;

SELECT verify_function('infra_utils.validate_params_schema');
SELECT verify_function('infra_utils.validate_params_schema_change');
SELECT verify_function('infra_utils.coerce_param_value');
SELECT verify_function('infra_utils.param_bound_magnitude');
SELECT verify_function('infra_utils.render_param_binding');
SELECT verify_function('infra_utils.compile_resource_spec');
SELECT verify_function('infra_utils.validate_bundle_params');
SELECT verify_function('infra_utils.bundle_param_interface');

ROLLBACK;

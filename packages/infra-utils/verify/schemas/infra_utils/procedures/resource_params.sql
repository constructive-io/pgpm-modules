-- Verify schemas/infra_utils/procedures/resource_params on pg

BEGIN;

SELECT assert_function('infra_utils.validate_params_schema(jsonb)'::regprocedure);
SELECT assert_function('infra_utils.validate_params_schema_change(jsonb, jsonb)'::regprocedure);
SELECT assert_function('infra_utils.coerce_param_value(jsonb, jsonb)'::regprocedure);
SELECT assert_function('infra_utils.param_bound_magnitude(text, jsonb)'::regprocedure);
SELECT assert_function('infra_utils.render_param_binding(jsonb, jsonb)'::regprocedure);
SELECT assert_function('infra_utils.compile_resource_spec(jsonb, jsonb, jsonb, text, jsonb)'::regprocedure);
SELECT assert_function('infra_utils.validate_bundle_params(jsonb, jsonb)'::regprocedure);
SELECT assert_function('infra_utils.bundle_param_interface(jsonb)'::regprocedure);

ROLLBACK;

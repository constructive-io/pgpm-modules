-- Revert schemas/infra_utils/procedures/resource_params from pg

BEGIN;

DROP FUNCTION IF EXISTS infra_utils.bundle_param_interface(jsonb);
DROP FUNCTION IF EXISTS infra_utils.validate_bundle_params(jsonb, jsonb);
DROP FUNCTION IF EXISTS infra_utils.compile_resource_spec(jsonb, jsonb, jsonb, text, jsonb);
DROP FUNCTION IF EXISTS infra_utils.render_param_binding(jsonb, jsonb);
DROP FUNCTION IF EXISTS infra_utils.param_bound_magnitude(text, jsonb);
DROP FUNCTION IF EXISTS infra_utils.coerce_param_value(jsonb, jsonb);
DROP FUNCTION IF EXISTS infra_utils.validate_params_schema_change(jsonb, jsonb);
DROP FUNCTION IF EXISTS infra_utils.validate_params_schema(jsonb);

COMMIT;

-- Verify schemas/infra_utils/procedures/resource_admission on pg

BEGIN;

SELECT assert_function('infra_utils.jsonb_has_key_deep(jsonb, text)'::regprocedure);
SELECT assert_function('infra_utils.check_resource_admission(text, text, jsonb, jsonb, jsonb, text)'::regprocedure);

ROLLBACK;

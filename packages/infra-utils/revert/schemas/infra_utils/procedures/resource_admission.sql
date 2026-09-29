-- Revert schemas/infra_utils/procedures/resource_admission from pg

BEGIN;

DROP FUNCTION infra_utils.check_resource_admission(text, text, jsonb, jsonb, jsonb, text);
DROP FUNCTION infra_utils.jsonb_has_key_deep(jsonb, text);

COMMIT;

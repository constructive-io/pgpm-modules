-- Revert schemas/jwt_private/procedures/require_entity_id from pg

BEGIN;

DROP FUNCTION jwt_private.require_entity_id();

COMMIT;

-- Revert schemas/jwt_private/procedures/current_entity_id from pg

BEGIN;

DROP FUNCTION jwt_private.current_entity_id();

COMMIT;

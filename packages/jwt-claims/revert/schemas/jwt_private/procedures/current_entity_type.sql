-- Revert schemas/jwt_private/procedures/current_entity_type from pg

BEGIN;

DROP FUNCTION jwt_private.current_entity_type();

COMMIT;

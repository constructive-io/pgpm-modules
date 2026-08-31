-- Revert schemas/jwt_private/procedures/assert_attribution from pg

BEGIN;

DROP FUNCTION jwt_private.assert_attribution(uuid, uuid, text);

COMMIT;

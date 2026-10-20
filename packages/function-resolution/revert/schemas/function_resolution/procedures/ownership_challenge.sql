-- Revert schemas/function_resolution/procedures/ownership_challenge from pg

BEGIN;

DROP FUNCTION function_resolution.ownership_challenge(
    host text,
    token text
);

COMMIT;

-- Revert schemas/errors/procedures/raise_error from pg

BEGIN;

DROP FUNCTION errors.raise_error(text, jsonb, text);

COMMIT;

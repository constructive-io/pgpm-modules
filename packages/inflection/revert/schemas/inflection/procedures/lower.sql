-- Revert schemas/inflection/procedures/lower from pg

BEGIN;

DROP FUNCTION inflection.lower(text);

COMMIT;

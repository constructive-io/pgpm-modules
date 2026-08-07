-- Revert schemas/inflection/procedures/no_consecutive_caps from pg

BEGIN;

DROP FUNCTION inflection.no_consecutive_caps(text);
DROP FUNCTION inflection.no_consecutive_caps_till_lower(text);
DROP FUNCTION inflection.no_consecutive_caps_till_end(text);

COMMIT;

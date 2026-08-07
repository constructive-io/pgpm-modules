-- Revert schemas/inflection/procedures/camel from pg

BEGIN;

DROP FUNCTION inflection.camel(text);

COMMIT;

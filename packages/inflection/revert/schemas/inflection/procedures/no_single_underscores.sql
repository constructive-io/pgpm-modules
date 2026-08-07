-- Revert schemas/inflection/procedures/no_single_underscores from pg

BEGIN;

DROP FUNCTION inflection.no_single_underscores(text);
DROP FUNCTION inflection.no_single_underscores_in_middle(text);
DROP FUNCTION inflection.no_single_underscores_at_end(text);
DROP FUNCTION inflection.no_single_underscores_in_beginning(text);

COMMIT;

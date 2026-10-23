-- Revert schemas/reserved_names/procedures/reserved_by from pg

BEGIN;

DROP FUNCTION reserved_names.reserved_by(text, text);

COMMIT;

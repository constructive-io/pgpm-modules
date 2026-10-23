-- Revert schemas/reserved_names/procedures/is_reserved from pg

BEGIN;

DROP FUNCTION reserved_names.is_reserved(text, text);

COMMIT;

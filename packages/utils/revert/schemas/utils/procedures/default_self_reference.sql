-- Revert schemas/utils/procedures/default_self_reference from pg

BEGIN;

DROP FUNCTION utils.default_self_reference();

COMMIT;

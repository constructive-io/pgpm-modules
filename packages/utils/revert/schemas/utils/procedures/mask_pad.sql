-- Revert schemas/utils/procedures/mask_pad from pg

BEGIN;

DROP FUNCTION utils.bitmask_pad(varbit, int4, text);
DROP FUNCTION utils.mask_pad(text, int4, text);

COMMIT;

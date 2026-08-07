-- Revert schemas/base32/procedures/decode from pg

BEGIN;

DROP FUNCTION base32.decode(text);
DROP FUNCTION base32.valid(text);
DROP FUNCTION base32.zero_fill(int4, int4);
DROP FUNCTION base32.base32_alphabet_to_decimal_int(text);
DROP FUNCTION base32.decimal_to_chunks(text[]);
DROP FUNCTION base32.base32_to_decimal(text);
DROP FUNCTION base32.base32_alphabet_to_decimal(text);

COMMIT;

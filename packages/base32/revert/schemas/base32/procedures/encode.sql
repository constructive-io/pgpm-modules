-- Revert schemas/base32/procedures/encode from pg

BEGIN;

DROP FUNCTION base32.encode(text);
DROP FUNCTION base32.to_base32(text[]);
DROP FUNCTION base32.base32_alphabet(int4);
DROP FUNCTION base32.to_decimal(text[]);
DROP FUNCTION base32.fill_chunks(text[]);
DROP FUNCTION base32.to_chunks(text[]);
DROP FUNCTION base32.string_nchars(text, int4);
DROP FUNCTION base32.to_groups(text[]);
DROP FUNCTION base32.to_binary(int4[]);
DROP FUNCTION base32.to_binary(int4);
DROP FUNCTION base32.to_ascii(text);
DROP FUNCTION base32.binary_to_int(text);

COMMIT;

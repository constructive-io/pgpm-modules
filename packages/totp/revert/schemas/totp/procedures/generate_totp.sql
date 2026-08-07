-- Revert schemas/totp/procedures/generate_totp from pg

BEGIN;

DROP FUNCTION totp.url(text, text, int4, text);
DROP FUNCTION totp.verify(text, text, int4, int4, timestamptz, text, text, int4);
DROP FUNCTION totp.timing_safe_equals(text, text);
DROP FUNCTION totp.timing_safe_equals(bytea, bytea);
DROP FUNCTION totp.generate(text, int4, int4, timestamptz, text, text, int4);
DROP FUNCTION totp.hotp(bytea, int4, int4, text);
DROP FUNCTION totp.base32_to_hex(text);
DROP FUNCTION totp.pad_secret(bytea, int4);

COMMIT;

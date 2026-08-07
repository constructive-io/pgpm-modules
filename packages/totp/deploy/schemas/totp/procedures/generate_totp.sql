-- Deploy schemas/totp/procedures/generate_totp to pg
-- requires: schemas/totp/schema
-- requires: schemas/totp/procedures/urlencode

BEGIN;

-- https://www.youtube.com/watch?v=VOYxF12K1vE
-- https://tools.ietf.org/html/rfc6238
-- http://blog.tinisles.com/2011/10/google-authenticator-one-time-password-algorithm-in-javascript/
-- https://gist.github.com/bwbroersma/676d0de32263ed554584ab132434ebd9

CREATE FUNCTION totp.pad_secret (
  input bytea,
  len int
) returns bytea as $$
DECLARE 
  output bytea;
  orig_length int = octet_length(input);
BEGIN
  IF (orig_length = len) THEN 
    RETURN input;
  END IF;

  -- create blank bytea size of new length
  output = lpad('', len, 'x')::bytea;

  FOR i IN 0 .. len-1 LOOP
    output = set_byte(output, i, get_byte(input, i % orig_length));
  END LOOP;

  RETURN output;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;

-- Decode a base32 secret straight to its hex representation. We intentionally
-- do NOT route through base32.decode(), which materialises the decoded bytes as
-- text via chr(): a decoded 0x00 byte raises "null character not permitted", so
-- TOTP generation failed for any secret whose bytes contain a null (roughly one
-- in twenty random secrets). Emitting hex per byte is binary-safe and produces
-- exactly the bytes base32.decode intends, so existing codes are unchanged.
CREATE FUNCTION totp.base32_to_hex (
  input text
) returns text as $$
DECLARE
  i int;
  len int;
  num int;
  clean text;
  value int = 0;
  bits int = 0;
  index int = 0;
  byte int;
  output text = '';
BEGIN
  IF (character_length(input) = 0) THEN
    RETURN '';
  END IF;

  IF (NOT base32.valid(input)) THEN
    RAISE EXCEPTION 'INVALID_BASE32';
  END IF;

  clean = upper(replace(input, '=', ''));
  len = character_length(clean);
  num = len * 5 / 8;

  FOR i IN 1 .. len LOOP
    value = (value << 5) | base32.base32_alphabet_to_decimal_int(substring(clean from i for 1));
    bits = bits + 5;
    IF (bits >= 8) THEN
      IF (index < num) THEN
        byte = base32.zero_fill(value, (bits - 8)) & 255;
        output = output || lpad(to_hex(byte), 2, '0');
        index = index + 1;
      END IF;
      bits = bits - 8;
    END IF;
  END LOOP;

  RETURN output;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;

CREATE FUNCTION totp.hotp(key BYTEA, c INT, digits INT DEFAULT 6, hash TEXT DEFAULT 'sha1') RETURNS TEXT AS $$
DECLARE
    c BYTEA := '\x' || LPAD(TO_HEX(c), 16, '0');
    mac BYTEA := HMAC(c, key, hash);
    trunc_offset INT := GET_BYTE(mac, length(mac) - 1) % 16;
    result TEXT := SUBSTRING(SET_BIT(SUBSTRING(mac FROM 1 + trunc_offset FOR 4), 7, 0)::TEXT, 2)::BIT(32)::INT % (10 ^ digits)::INT;
BEGIN
    RETURN LPAD(result, digits, '0');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE FUNCTION totp.generate(
    secret text, 
    period int DEFAULT 30,
    digits int DEFAULT 6, 
    time_from timestamptz DEFAULT NOW(),
    hash text DEFAULT 'sha1',
    encoding text DEFAULT 'base32',
    clock_offset int DEFAULT 0
) RETURNS text AS $$
DECLARE
    c int := FLOOR(EXTRACT(EPOCH FROM time_from) / period)::int + clock_offset;
    key bytea;
BEGIN

  IF (encoding = 'base32') THEN 
    key = ( '\x' || totp.base32_to_hex(secret) )::bytea;
  ELSE 
    key = secret::bytea;
  END IF;

  RETURN totp.hotp(key, c, digits, hash);
END;
$$ LANGUAGE plpgsql STABLE;

-- Mitigate timing attacks by using constant-time comparison.
-- Mitigates timing attacks by avoiding early-exit and content-dependent work; compares full byte sequences in a length-oblivious loop.
-- Context: HN discussion on TOTP '=' comparison timing leaks: https://news.ycombinator.com/item?id=26260667

-- Context: https://news.ycombinator.com/item?id=26260667

CREATE FUNCTION totp.timing_safe_equals(a bytea, b bytea)
RETURNS boolean
AS $$
DECLARE
  la int := length(a);
  lb int := length(b);
  maxlen int := GREATEST(la, lb);
  i int;
  diff int := la # lb;
  ca int;
  cb int;
BEGIN
  FOR i IN 0..(maxlen - 1) LOOP
    ca := CASE WHEN i < la THEN get_byte(a, i) ELSE 0 END;
    cb := CASE WHEN i < lb THEN get_byte(b, i) ELSE 0 END;
    diff := diff | (ca # cb);
  END LOOP;
  RETURN diff = 0;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

CREATE FUNCTION totp.timing_safe_equals(a text, b text)
RETURNS boolean
AS $$
-- Verify uses timing-safe equality to avoid leaking mismatch position via timing; do not use direct '=' here.
-- See HN discussion for background: https://news.ycombinator.com/item?id=26260667

  SELECT totp.timing_safe_equals(convert_to(a, 'UTF8'), convert_to(b, 'UTF8'));
$$ LANGUAGE sql IMMUTABLE STRICT;

CREATE FUNCTION totp.verify (
  secret text,
  check_totp text,
  period int default 30,
  digits int default 6,
  time_from timestamptz DEFAULT NOW(),
  hash text default 'sha1',
  encoding text DEFAULT 'base32',
  clock_offset int default 0
)
  RETURNS boolean
  AS $$
  SELECT totp.timing_safe_equals(
    totp.generate(
      secret,
      period,
      digits,
      time_from,
      hash,
      encoding,
      clock_offset
    ),
    check_totp
  );
$$
LANGUAGE 'sql';

CREATE FUNCTION totp.url (email text, totp_secret text, totp_interval int, totp_issuer text)
  RETURNS text
  AS $$
  SELECT
    concat('otpauth://totp/', totp.urlencode (email), '?secret=', totp.urlencode (totp_secret), '&period=', totp.urlencode (totp_interval::text), '&issuer=', totp.urlencode (totp_issuer));
$$
LANGUAGE 'sql'
STRICT IMMUTABLE;

COMMIT;


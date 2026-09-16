\echo Use "CREATE EXTENSION pgpm-types" to load this file. \quit
CREATE DOMAIN attachment AS text 
  CHECK (value ~ E'^https?://[^\\s]+$');

COMMENT ON DOMAIN attachment IS '@name constructiveInternalTypeAttachment';

CREATE DOMAIN email AS citext 
  CHECK (value ~ '@');

COMMENT ON DOMAIN email IS '@name constructiveInternalTypeEmail';

CREATE DOMAIN hostname AS text 
  CHECK (value ~ E'^[^\\s]+$');

COMMENT ON DOMAIN hostname IS '@name constructiveInternalTypeHostname';

CREATE DOMAIN image AS jsonb 
  CHECK (
  jsonb_typeof(value) = 'object'
    AND (value ? 'url'
    OR value ? 'id'
    OR value ? 'key')
    AND (NOT (value ? 'url')
    OR (value ->> 'url') ~ E'^https?://[^\\s]+$')
    AND (NOT (value ? 'id')
    OR jsonb_typeof(value -> 'id') = 'string')
    AND (NOT (value ? 'key')
    OR jsonb_typeof(value -> 'key') = 'string')
    AND (NOT (value ? 'bucket')
    OR jsonb_typeof(value -> 'bucket') = 'string')
    AND (NOT (value ? 'provider')
    OR jsonb_typeof(value -> 'provider') = 'string')
    AND (NOT (value ? 'mime')
    OR jsonb_typeof(value -> 'mime') = 'string')
    AND (NOT (value ? 'versions')
    OR jsonb_typeof(value -> 'versions') = 'array')
);

COMMENT ON DOMAIN image IS '@name constructiveInternalTypeImage';

CREATE DOMAIN origin AS text 
  CHECK (value ~ E'^https?://[^/\\s]+$');

COMMENT ON DOMAIN origin IS '@name constructiveInternalTypeOrigin';

CREATE DOMAIN upload AS jsonb 
  CHECK (
  jsonb_typeof(value) = 'object'
    AND (value ? 'url'
    OR value ? 'id'
    OR value ? 'key')
    AND (NOT (value ? 'url')
    OR (value ->> 'url') ~ E'^https?://[^\\s]+$')
    AND (NOT (value ? 'id')
    OR jsonb_typeof(value -> 'id') = 'string')
    AND (NOT (value ? 'key')
    OR jsonb_typeof(value -> 'key') = 'string')
    AND (NOT (value ? 'bucket')
    OR jsonb_typeof(value -> 'bucket') = 'string')
    AND (NOT (value ? 'provider')
    OR jsonb_typeof(value -> 'provider') = 'string')
    AND (NOT (value ? 'mime')
    OR jsonb_typeof(value -> 'mime') = 'string')
);

COMMENT ON DOMAIN upload IS '@name constructiveInternalTypeUpload';

CREATE DOMAIN url AS text 
  CHECK (value ~ E'^https?://[^\\s]+$');

COMMENT ON DOMAIN url IS '@name constructiveInternalTypeUrl';

ALTER DOMAIN upload DROP CONSTRAINT upload_check;

ALTER DOMAIN upload ADD CONSTRAINT upload_check 
  CHECK (
  jsonb_typeof(value) = 'object'
    AND (value ? 'url'
    OR value ? 'id'
    OR value ? 'key')
    AND (NOT (value ? 'url')
    OR (value ->> 'url') ~ E'^https?://[^\\s]+$')
    AND (NOT (value ? 'id')
    OR jsonb_typeof(value -> 'id') = 'string')
    AND (NOT (value ? 'key')
    OR jsonb_typeof(value -> 'key') = 'string')
    AND (NOT (value ? 'bucket')
    OR jsonb_typeof(value -> 'bucket') = 'string')
    AND (NOT (value ? 'bucket_id')
    OR (value ->> 'bucket_id') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
    AND (NOT (value ? 'provider')
    OR jsonb_typeof(value -> 'provider') = 'string')
    AND (NOT (value ? 'mime')
    OR jsonb_typeof(value -> 'mime') = 'string')
    AND (NOT (value ? 'size')
    OR jsonb_typeof(value -> 'size') = 'number')
    AND (NOT (value ? 'filename')
    OR jsonb_typeof(value -> 'filename') = 'string')
);

ALTER DOMAIN image DROP CONSTRAINT image_check;

ALTER DOMAIN image ADD CONSTRAINT image_check 
  CHECK (
  jsonb_typeof(value) = 'object'
    AND (value ? 'url'
    OR value ? 'id'
    OR value ? 'key')
    AND (NOT (value ? 'url')
    OR (value ->> 'url') ~ E'^https?://[^\\s]+$')
    AND (NOT (value ? 'id')
    OR jsonb_typeof(value -> 'id') = 'string')
    AND (NOT (value ? 'key')
    OR jsonb_typeof(value -> 'key') = 'string')
    AND (NOT (value ? 'bucket')
    OR jsonb_typeof(value -> 'bucket') = 'string')
    AND (NOT (value ? 'bucket_id')
    OR (value ->> 'bucket_id') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
    AND (NOT (value ? 'provider')
    OR jsonb_typeof(value -> 'provider') = 'string')
    AND (NOT (value ? 'mime')
    OR jsonb_typeof(value -> 'mime') = 'string')
    AND (NOT (value ? 'size')
    OR jsonb_typeof(value -> 'size') = 'number')
    AND (NOT (value ? 'filename')
    OR jsonb_typeof(value -> 'filename') = 'string')
    AND (NOT (value ? 'versions')
    OR jsonb_typeof(value -> 'versions') = 'array')
);

CREATE FUNCTION upload_ids(
  uploads upload[]
) RETURNS text[] AS $EOFCODE$
  SELECT COALESCE(
    array_agg(u.value ->> 'id' ORDER BY u.ordinality),
    ARRAY[]::text[]
  )
  FROM unnest(uploads) WITH ORDINALITY AS u(value, ordinality)
  WHERE u.value ? 'id';
$EOFCODE$ LANGUAGE sql IMMUTABLE STRICT PARALLEL safe;

COMMENT ON FUNCTION upload_ids(upload[]) IS '@omit';
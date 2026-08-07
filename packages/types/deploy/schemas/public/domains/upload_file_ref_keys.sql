-- Deploy schemas/public/domains/upload_file_ref_keys to pg
-- requires: schemas/public/domains/upload

BEGIN;

ALTER DOMAIN upload DROP CONSTRAINT upload_check;

ALTER DOMAIN upload ADD CONSTRAINT upload_check CHECK (
  jsonb_typeof(value) = 'object'
  AND (value ? 'url' OR value ? 'id' OR value ? 'key')
  AND (NOT value ? 'url' OR (value->>'url') ~ '^https?://[^\s]+$')
  AND (NOT value ? 'id' OR jsonb_typeof(value->'id') = 'string')
  AND (NOT value ? 'key' OR jsonb_typeof(value->'key') = 'string')
  AND (NOT value ? 'bucket' OR jsonb_typeof(value->'bucket') = 'string')
  AND (NOT value ? 'bucket_id' OR (value->>'bucket_id') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
  AND (NOT value ? 'provider' OR jsonb_typeof(value->'provider') = 'string')
  AND (NOT value ? 'mime' OR jsonb_typeof(value->'mime') = 'string')
  AND (NOT value ? 'size' OR jsonb_typeof(value->'size') = 'number')
  AND (NOT value ? 'filename' OR jsonb_typeof(value->'filename') = 'string')
);

COMMIT;

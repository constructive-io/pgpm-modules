-- Revert schemas/public/domains/upload_file_ref_keys from pg

BEGIN;

ALTER DOMAIN upload DROP CONSTRAINT upload_check;

ALTER DOMAIN upload ADD CONSTRAINT upload_check CHECK (
  jsonb_typeof(value) = 'object'
  AND (value ? 'url' OR value ? 'id' OR value ? 'key')
  AND (NOT value ? 'url' OR (value->>'url') ~ '^https?://[^\s]+$')
  AND (NOT value ? 'id' OR jsonb_typeof(value->'id') = 'string')
  AND (NOT value ? 'key' OR jsonb_typeof(value->'key') = 'string')
  AND (NOT value ? 'bucket' OR jsonb_typeof(value->'bucket') = 'string')
  AND (NOT value ? 'provider' OR jsonb_typeof(value->'provider') = 'string')
  AND (NOT value ? 'mime' OR jsonb_typeof(value->'mime') = 'string')
);

COMMIT;

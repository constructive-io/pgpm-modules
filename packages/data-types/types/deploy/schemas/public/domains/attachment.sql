-- Deploy schemas/public/domains/attachment to pg
-- requires: schemas/public/schema

BEGIN;
CREATE DOMAIN attachment AS jsonb CHECK (
  (
    jsonb_typeof(VALUE) = 'object'
    AND VALUE ?& ARRAY['url', 'mime']
    AND VALUE->>'url' ~ '^(https?)://[^\\s/$.?#].[^\\s]*$'
  )
  OR (
    jsonb_typeof(VALUE) = 'string'
    AND VALUE #>> '{}' ~ '^(https?)://[^\\s/$.?#].[^\\s]*$'
  )
);
COMMENT ON DOMAIN attachment IS E'@name launchqlInternalTypeAttachment';
COMMIT;

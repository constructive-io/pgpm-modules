-- Deploy schemas/function_resolution/procedures/staging_bucket_tag to pg

-- requires: schemas/function_resolution/schema

BEGIN;

-- staging_bucket_tag: the reserved tag for "the bucket this module stages
-- uploads through before they are promoted", in one place.
--
-- Third label in the same reserved vocabulary default_bucket_tag owns
-- ('default', 'default-public'), for the same reason: staging is a bucket a
-- tenant labelled, resolved by the tag rule capabilities already use, not a
-- boolean on the row. A staging bucket is additionally a 'temp' bucket, so
-- resolution filters on type as well and a mislabelled permanent bucket cannot
-- become a staging destination by tag alone.
CREATE FUNCTION function_resolution.staging_bucket_tag() RETURNS text AS $$
    SELECT 'default-temp';
$$ LANGUAGE sql IMMUTABLE;

COMMIT;

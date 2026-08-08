-- Deploy schemas/function_resolution/procedures/default_bucket_tag to pg

-- requires: schemas/function_resolution/schema

BEGIN;

-- default_bucket_tag: the reserved tag vocabulary for "the bucket this database
-- uses when nobody named one", in one place.
--
-- A database's default bucket is not a column, a setting or a flag: it is a
-- bucket a tenant labelled, resolved by the same tag rule capabilities use.
-- Two reserved labels, because "the default" is two questions:
--   default        -- the private default (presigned GET)
--   default-public -- the CDN-served default (public reads)
--
-- Reserved only by convention plus provisioning: storage bootstrap applies them,
-- and resolution reads them. A tenant that retags its own buckets changes which
-- bucket is default, and a tenant that applies a label twice gets a loud
-- ambiguity rather than a silent winner.
CREATE FUNCTION function_resolution.default_bucket_tag(
    public_access boolean
) RETURNS text AS $$
    SELECT CASE WHEN default_bucket_tag.public_access THEN 'default-public' ELSE 'default' END;
$$ LANGUAGE sql IMMUTABLE;

COMMIT;

-- Deploy schemas/public/procedures/upload_ids to pg
-- requires: schemas/public/schema
-- requires: schemas/public/domains/upload

BEGIN;

-- The file ids an upload array refers to, as text, in element order.
--
-- One indexable expression for a column holding many uploads. A scalar upload
-- column answers "which file is this?" with (value ->> 'id'), which a btree
-- expression index serves; an array cannot, so storage garbage collection and
-- the files-to-document sync trigger both key off this function instead, and
-- metaschema_generators.file_ref_field emits a GIN index over it. Without the
-- index those two questions cost a sequential scan of tenant data per candidate
-- object.
--
-- IMMUTABLE and NULL-free: an index expression must be immutable, and an
-- element with no id (an upload naming only a url, which the domain allows) is
-- not a reference to a files row, so it contributes nothing rather than a NULL
-- that && would have to reason about.
CREATE FUNCTION upload_ids(uploads upload[])
RETURNS text[] AS $$
  SELECT COALESCE(
    array_agg(u.value ->> 'id' ORDER BY u.ordinality),
    ARRAY[]::text[]
  )
  FROM unnest(uploads) WITH ORDINALITY AS u(value, ordinality)
  WHERE u.value ? 'id';
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION upload_ids(upload[]) IS E'@omit';

COMMIT;

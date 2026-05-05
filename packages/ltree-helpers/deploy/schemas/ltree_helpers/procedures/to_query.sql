-- Deploy schemas/ltree_helpers/procedures/to_query to pg

-- requires: schemas/ltree_helpers/schema

BEGIN;

-- Convert a glob-style path to an lquery value.
-- '/projects/*/docs'  => 'projects.*.docs'
-- '/projects/**'      => 'projects.*{1,}'
CREATE FUNCTION ltree_helpers.to_query(
  glob text
) RETURNS lquery AS $$
  SELECT replace(
    replace(ltrim(glob, '/'), '**', '*{1,}'),
    '/', '.'
  )::lquery;
$$ LANGUAGE sql IMMUTABLE STRICT;

COMMIT;

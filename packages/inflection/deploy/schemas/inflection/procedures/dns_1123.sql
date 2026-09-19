-- Deploy schemas/inflection/procedures/dns_1123 to pg

-- requires: schemas/inflection/schema

-- Kubernetes DNS-1123 label normalizer. Mirrors toK8sName in
-- compute/lib/module-loader/src/k8s-name.ts and must stay in lockstep with it:
-- lowercase, ':' -> '--', '_' -> '-', strip invalid chars, trim
-- leading/trailing hyphens. A result within 63 chars is returned as is; a
-- longer one is cut to a 50-char head and suffixed with '-' and the first 12
-- hex digits of sha256(original value), so two values that agree on their
-- first 63 mapped chars still get distinct labels.

BEGIN;

CREATE FUNCTION inflection.dns_1123 (value text)
  RETURNS text
  AS $$
  WITH lowercased AS (
    SELECT
      lower(value) AS value
),
-- ':' delimits namespaced identifiers; map to '--' so the boundary survives
namespaced AS (
  SELECT
    replace(value, ':', '--') AS value
FROM
  lowercased
),
hyphenated AS (
  SELECT
    replace(value, '_', '-') AS value
FROM
  namespaced
),
stripped AS (
  SELECT
    regexp_replace(value, '[^a-z0-9-]', '', 'g') AS value
FROM
  hyphenated
),
trimmed AS (
  SELECT
    regexp_replace(value, '^-+|-+$', '', 'g') AS value
FROM
  stripped
),
digested AS (
  SELECT
    regexp_replace("left"(value, 50), '-+$', '') || '-' || "left"(encode(sha256(convert_to(dns_1123.value, 'UTF8')), 'hex'), 12) AS value
FROM
  trimmed
)
SELECT
  CASE WHEN length(trimmed.value) <= 63 THEN
    trimmed.value
  ELSE
    digested.value
  END
FROM
  trimmed,
  digested;
$$
LANGUAGE SQL
STRICT IMMUTABLE;

COMMIT;

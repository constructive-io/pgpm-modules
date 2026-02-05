\echo Use "CREATE EXTENSION pgpm-types" to load this file. \quit
CREATE DOMAIN attachment AS text;

COMMENT ON DOMAIN attachment IS '@name constructiveInternalTypeAttachment';

CREATE DOMAIN email AS citext;

COMMENT ON DOMAIN email IS '@name constructiveInternalTypeEmail';

CREATE DOMAIN hostname AS text;

COMMENT ON DOMAIN hostname IS '@name constructiveInternalTypeHostname';

CREATE DOMAIN image AS jsonb 
  CHECK (value ? 'url');

COMMENT ON DOMAIN image IS '@name constructiveInternalTypeImage';

CREATE DOMAIN origin AS text;

COMMENT ON DOMAIN origin IS '@name constructiveInternalTypeOrigin';

CREATE DOMAIN upload AS jsonb 
  CHECK (
  value ? 'url'
    OR value ? 'id'
    OR value ? 'key'
);

COMMENT ON DOMAIN upload IS '@name constructiveInternalTypeUpload';

CREATE DOMAIN url AS text;

COMMENT ON DOMAIN url IS '@name constructiveInternalTypeUrl';
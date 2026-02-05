-- Deploy schemas/public/domains/url to pg
-- requires: schemas/public/schema

BEGIN;
CREATE DOMAIN url AS text CHECK (value LIKE 'http://%' OR value LIKE 'https://%');
COMMENT ON DOMAIN url IS E'@name constructiveInternalTypeUrl';
COMMIT;


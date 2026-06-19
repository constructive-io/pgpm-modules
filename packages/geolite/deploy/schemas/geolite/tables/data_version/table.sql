-- Deploy schemas/geolite/tables/data_version/table to pg

-- requires: schemas/geolite/schema

BEGIN;

CREATE TABLE geolite.data_version (
  id          uuid        PRIMARY KEY DEFAULT uuidv7(),
  version     text        NOT NULL,
  loaded_at   timestamptz NOT NULL DEFAULT now(),
  source_url  text
);

COMMENT ON TABLE geolite.data_version IS 'Tracks which GeoLite2 release is currently loaded';
COMMENT ON COLUMN geolite.data_version.version IS 'GeoLite2 release version or date tag';
COMMENT ON COLUMN geolite.data_version.loaded_at IS 'Timestamp when data was last loaded';
COMMENT ON COLUMN geolite.data_version.source_url IS 'URL the data was downloaded from';

GRANT SELECT ON TABLE geolite.data_version TO public;

COMMIT;

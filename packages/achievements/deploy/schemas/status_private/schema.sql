-- Deploy schemas/status_private/schema to pg

BEGIN;

CREATE SCHEMA IF NOT EXISTS status_private;

GRANT USAGE ON SCHEMA status_private
TO authenticated, anonymous;

COMMIT;

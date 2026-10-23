-- Deploy schemas/stamps/schema to pg

BEGIN;

CREATE SCHEMA stamps;

GRANT USAGE ON SCHEMA stamps
TO authenticated, anonymous;

COMMIT;

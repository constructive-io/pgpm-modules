-- Deploy schemas/jwt_private/schema to pg

BEGIN;

CREATE SCHEMA jwt_private;

GRANT USAGE ON SCHEMA jwt_private
TO authenticated, anonymous;

COMMIT;

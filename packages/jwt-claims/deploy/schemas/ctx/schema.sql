-- Deploy schemas/ctx/schema to pg

BEGIN;

CREATE SCHEMA ctx;

GRANT USAGE ON SCHEMA ctx
TO authenticated, anonymous;

COMMIT;


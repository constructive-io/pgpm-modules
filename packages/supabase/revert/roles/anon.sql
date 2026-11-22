-- Revert roles/anon from pg

BEGIN;

REVOKE anonymous FROM anon;

COMMIT;

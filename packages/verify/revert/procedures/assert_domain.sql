-- Revert procedures/assert_domain from pg

BEGIN;

DROP FUNCTION assert_domain(regtype, regtype, bool, int4);

COMMIT;

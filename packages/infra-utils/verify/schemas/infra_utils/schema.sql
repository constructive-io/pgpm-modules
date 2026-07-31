-- Verify schemas/infra_utils/schema  on pg

BEGIN;

SELECT verify_schema ('infra_utils');

ROLLBACK;

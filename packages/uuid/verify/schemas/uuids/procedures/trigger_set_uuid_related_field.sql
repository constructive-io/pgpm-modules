-- Verify schemas/uuids/procedures/trigger_set_uuid_related_field  on pg

BEGIN;

SELECT assert_function('uuids.trigger_set_uuid_related_field()'::regprocedure);

ROLLBACK;

-- Verify schemas/metaschema_public/tables/domain_type/table on pg

BEGIN;

SELECT verify_table ('metaschema_public.domain_type');

ROLLBACK;

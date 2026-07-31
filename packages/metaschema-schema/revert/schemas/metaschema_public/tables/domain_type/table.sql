-- Revert schemas/metaschema_public/tables/domain_type/table from pg

BEGIN;

DROP TABLE metaschema_public.domain_type;

COMMIT;

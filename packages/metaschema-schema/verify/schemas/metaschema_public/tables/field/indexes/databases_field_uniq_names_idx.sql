-- Verify schemas/metaschema_public/tables/field/indexes/databases_field_uniq_names_idx  on pg

BEGIN;

SELECT assert_index('metaschema_public.databases_field_uniq_names_idx'::regclass, 'metaschema_public.field'::regclass, true);

ROLLBACK;

-- Revert: schemas/collections_public/tables/schema_grant/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE collections_public.schema_grant FROM authenticated;
COMMIT;  


-- Revert: schemas/collections_public/tables/table_grant/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE collections_public.table_grant FROM authenticated;
COMMIT;  


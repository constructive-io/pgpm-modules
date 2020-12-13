-- Revert: schemas/collections_public/tables/table_grant/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE collections_public.table_grant FROM authenticated;
COMMIT;  


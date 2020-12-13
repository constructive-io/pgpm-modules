-- Revert: schemas/collections_public/tables/table_grant/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE collections_public.table_grant FROM authenticated;
COMMIT;  


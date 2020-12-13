-- Revert: schemas/collections_public/tables/schema/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE collections_public.schema FROM authenticated;
COMMIT;  


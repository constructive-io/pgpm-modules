-- Revert: schemas/collections_public/tables/schema/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE collections_public.schema FROM authenticated;
COMMIT;  


-- Revert: schemas/collections_public/tables/schema/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE collections_public.schema FROM authenticated;
COMMIT;  


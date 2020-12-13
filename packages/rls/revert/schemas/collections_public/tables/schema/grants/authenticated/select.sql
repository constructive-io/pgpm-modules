-- Revert: schemas/collections_public/tables/schema/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE collections_public.schema FROM authenticated;
COMMIT;  


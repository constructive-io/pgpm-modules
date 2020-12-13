-- Revert: schemas/collections_public/tables/index/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE collections_public.index FROM authenticated;
COMMIT;  


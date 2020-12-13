-- Revert: schemas/collections_public/tables/index/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE collections_public.index FROM authenticated;
COMMIT;  


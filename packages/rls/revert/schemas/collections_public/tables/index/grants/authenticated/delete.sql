-- Revert: schemas/collections_public/tables/index/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE collections_public.index FROM authenticated;
COMMIT;  


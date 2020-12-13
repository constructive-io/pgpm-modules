-- Revert: schemas/collections_public/tables/index/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE collections_public.index FROM authenticated;
COMMIT;  


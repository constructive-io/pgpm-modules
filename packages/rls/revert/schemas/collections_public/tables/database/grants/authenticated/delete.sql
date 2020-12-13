-- Revert: schemas/collections_public/tables/database/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE collections_public.database FROM authenticated;
COMMIT;  


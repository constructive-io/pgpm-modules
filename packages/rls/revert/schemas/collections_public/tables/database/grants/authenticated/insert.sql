-- Revert: schemas/collections_public/tables/database/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE collections_public.database FROM authenticated;
COMMIT;  


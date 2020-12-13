-- Revert: schemas/collections_public/tables/database/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE collections_public.database FROM authenticated;
COMMIT;  


-- Revert: schemas/collections_public/tables/database/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE collections_public.database FROM authenticated;
COMMIT;  


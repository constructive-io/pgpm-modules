-- Verify: schemas/collections_public/tables/database/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('collections_public.database', 'select', 'authenticated');
COMMIT;  


-- Verify: schemas/collections_public/tables/database/grants/authenticated/delete on pg

BEGIN;
SELECT verify_table_grant('collections_public.database', 'delete', 'authenticated');
COMMIT;  


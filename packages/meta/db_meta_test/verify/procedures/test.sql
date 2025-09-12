-- Verify procedures/test  on pg

BEGIN;

-- Verify that test data was inserted correctly
SELECT 1 FROM collections_public.database WHERE name = 'meta_db';
SELECT 1 FROM meta_public.sites WHERE title = 'Title';
SELECT 1 FROM meta_public.apps WHERE name = 'My App';

ROLLBACK;

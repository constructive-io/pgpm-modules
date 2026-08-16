-- Verify schemas/public/procedures/upload_ids on pg

BEGIN;

SELECT has_function_privilege('public.upload_ids(upload[])', 'execute');

DO $$
DECLARE
  v_ids text[];
BEGIN
  v_ids := public.upload_ids(ARRAY[
    '{"id": "0d1e3d64-1e2a-4c7f-9c3a-6f7f9f2b1c44", "key": "a.png"}'::jsonb::public.upload,
    '{"url": "https://example.com/b.png"}'::jsonb::public.upload,
    '{"id": "9a7f1c2e-4b6d-4a11-8f30-2c5d7e9a0b13", "key": "c.png"}'::jsonb::public.upload
  ]);

  -- Element order is preserved and an element carrying no id is not a reference.
  IF v_ids <> ARRAY[
    '0d1e3d64-1e2a-4c7f-9c3a-6f7f9f2b1c44',
    '9a7f1c2e-4b6d-4a11-8f30-2c5d7e9a0b13'
  ] THEN
    RAISE EXCEPTION 'public.upload_ids returned %', v_ids;
  END IF;

  IF public.upload_ids(ARRAY[]::public.upload[]) <> ARRAY[]::text[] THEN
    RAISE EXCEPTION 'public.upload_ids did not return an empty array for no uploads';
  END IF;
END
$$;

ROLLBACK;

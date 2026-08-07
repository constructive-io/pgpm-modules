-- Verify schemas/public/domains/upload_file_ref_keys on pg

BEGIN;

SELECT assert_domain('public.upload'::regtype, 'jsonb'::regtype, _constraints => 1);

DO $$
BEGIN
  PERFORM '{"id": "0d1e3d64-1e2a-4c7f-9c3a-6f7f9f2b1c44", "key": "abc", "bucket_id": "9a7f1c2e-4b6d-4a11-8f30-2c5d7e9a0b13", "size": 12345, "filename": "hero.png"}'::jsonb::public.upload;

  BEGIN
    PERFORM '{"id": "abc", "bucket_id": "not-a-uuid"}'::jsonb::public.upload;
    RAISE EXCEPTION 'public.upload accepted a bucket_id that is not a uuid';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  BEGIN
    PERFORM '{"id": "abc", "size": "12345"}'::jsonb::public.upload;
    RAISE EXCEPTION 'public.upload accepted a size that is not a number';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  PERFORM '{"url": "https://example.com/hero.png", "mime": "image/png"}'::jsonb::public.upload;
END
$$;

ROLLBACK;

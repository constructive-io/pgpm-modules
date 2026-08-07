-- Verify schemas/public/domains/upload on pg

BEGIN;

SELECT assert_domain('public.upload'::regtype, 'jsonb'::regtype, _constraints => 1);

ROLLBACK;

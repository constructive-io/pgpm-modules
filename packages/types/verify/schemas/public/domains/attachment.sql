-- Verify schemas/public/domains/attachment on pg

BEGIN;

SELECT assert_domain('public.attachment'::regtype, 'text'::regtype, _constraints => 1);

ROLLBACK;

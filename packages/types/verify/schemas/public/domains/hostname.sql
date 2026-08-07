-- Verify schemas/public/domains/hostname on pg

BEGIN;

SELECT assert_domain('public.hostname'::regtype, 'text'::regtype, _constraints => 1);

ROLLBACK;

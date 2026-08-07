-- Verify schemas/public/domains/email on pg

BEGIN;

SELECT assert_domain('public.email'::regtype, 'citext'::regtype, _constraints => 1);

ROLLBACK;

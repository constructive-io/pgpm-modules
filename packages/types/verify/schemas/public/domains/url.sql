-- Verify schemas/public/domains/url on pg

BEGIN;

SELECT assert_domain('public.url'::regtype, 'text'::regtype, _constraints => 1);

ROLLBACK;

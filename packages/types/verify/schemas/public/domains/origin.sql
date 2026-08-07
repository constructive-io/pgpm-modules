-- Verify schemas/public/domains/origin on pg

BEGIN;

SELECT assert_domain('public.origin'::regtype, 'text'::regtype, _constraints => 1);

ROLLBACK;

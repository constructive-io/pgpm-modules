-- Verify schemas/public/domains/image on pg

BEGIN;

SELECT assert_domain('public.image'::regtype, 'jsonb'::regtype, _constraints => 1);

ROLLBACK;

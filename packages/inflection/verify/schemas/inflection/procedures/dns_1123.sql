-- Verify schemas/inflection/procedures/dns_1123  on pg

BEGIN;

SELECT assert_function('inflection.dns_1123(text)'::regprocedure);

ROLLBACK;

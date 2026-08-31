-- Verify schemas/metaschema_public/tables/function/table on pg

BEGIN;

SELECT id, database_id, schema_id, name, kind, arguments, returns, volatility,
       is_strict, security_invoker, function_type, data, body_ast, smart_tags,
       api_exposed, category, tags
FROM metaschema_public.function
WHERE FALSE;

ROLLBACK;

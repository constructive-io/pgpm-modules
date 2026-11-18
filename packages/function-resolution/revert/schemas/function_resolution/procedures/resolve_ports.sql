-- Revert schemas/function_resolution/procedures/resolve_ports from pg

BEGIN;

DROP FUNCTION function_resolution.resolve_ports(uuid, text, uuid, text);

COMMIT;

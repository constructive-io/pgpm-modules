-- Deploy schemas/function_resolution/procedures/resolve_ports to pg
-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/resolve

BEGIN;

-- resolve_ports: the declared ports of the function definition a task
-- identifier resolves to, in the shape of a graph NodeDefinition
-- ({name, inputs, outputs}), or NULL when the scope chain has no definition.
--
-- This is the graph engine's registry fallback for branch semantics:
-- a graph that wires a registered
-- function such as flow:switch without embedding its definition still has
-- declared output ports — the registry's — so a port absent from a completed
-- output is a branch not taken, not PORT_NOT_FOUND. The same chain dispatch
-- walks (function_resolution.resolve) names the winning row, and the ports
-- are read from that one static catalog row: the catalog carries inputs and
-- outputs for exactly this reason, so no scoped source table is located or
-- read dynamically.
CREATE FUNCTION function_resolution.resolve_ports(
    database_id uuid,
    scope text,
    entity_id uuid,
    task_identifier text
) RETURNS jsonb AS $$
DECLARE
    v_definition jsonb;
BEGIN
    SELECT jsonb_build_object(
        'name', c.task_identifier,
        'inputs', c.inputs,
        'outputs', c.outputs
    )
    INTO v_definition
    FROM function_resolution.resolve(
        resolve_ports.database_id,
        resolve_ports.scope,
        resolve_ports.entity_id,
        resolve_ports.task_identifier,
        false
    ) r
    JOIN catalog_private.functions c ON c.id = r.function_definition_id;

    RETURN v_definition;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Reached only from the SECURITY DEFINER tick procedures; no request role calls it.
REVOKE ALL ON FUNCTION function_resolution.resolve_ports(uuid, text, uuid, text) FROM PUBLIC;

COMMIT;

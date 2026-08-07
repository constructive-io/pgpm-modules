-- Deploy schemas/function_resolution/procedures/validate_capabilities to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/resolve_capabilities

BEGIN;

-- validate_capabilities: prove an invocation's declarations can be satisfied,
-- without keeping the bundle.
--
-- Deliberately a thin wrapper over resolve_capabilities rather than a parallel
-- set of checks: validation that does not run the real resolution eventually
-- disagrees with it, and then a deploy-time check passes while dispatch fails.
-- Every requirement kind is therefore validated by resolving it — buckets
-- (declared key -> binding or tags), apis (semantic selector), the payload's
-- typed refs, the channel/lane, and the reachability of every bound target.
--
-- Secret, config, model and integration requirements are returned by resolution
-- as declared names and are not resolved here: their values live per realm and
-- are fetched inside the runtime, and integration requirements are copied into
-- the definition at authoring time on purpose — a later edit to a provider row
-- must not silently change what an already-deployed function requires.
CREATE FUNCTION function_resolution.validate_capabilities(
    database_id uuid,
    scope text,
    entity_id uuid,
    function_definition_id uuid,
    definition_scope text,
    definition_database_id uuid DEFAULT NULL,
    payload jsonb DEFAULT '{}'::jsonb,
    channel text DEFAULT NULL
) RETURNS void AS $$
BEGIN
    PERFORM function_resolution.resolve_capabilities(
        validate_capabilities.database_id,
        validate_capabilities.scope,
        validate_capabilities.entity_id,
        validate_capabilities.function_definition_id,
        validate_capabilities.definition_scope,
        validate_capabilities.definition_database_id,
        validate_capabilities.payload,
        validate_capabilities.channel
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;

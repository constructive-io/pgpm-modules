-- Deploy schemas/function_resolution/procedures/routing to pg
-- requires: schemas/function_resolution/schema

BEGIN;

-- routing: load the queue-routing fields (queue_name, priority, max_attempts)
-- from ONE already-resolved function definition.
--
-- The catalog row carries the routing fields (copied from the source definition
-- by the catalog-sync triggers) and its id IS the source definition's id, so
-- this is one primary-key read of catalog_private.functions: resolution and
-- routing answer from the same row, and the scoped source definitions table is
-- never touched on the dispatch path.
--
-- The database_id predicate is what keeps one tenant from reading another's row
-- off the shared plane, even if an id were guessed. Returns no row when the id
-- is absent, letting the caller fall back to queue defaults.
CREATE FUNCTION function_resolution.routing(
    database_id uuid,
    function_definition_id uuid
) RETURNS TABLE (
    queue_name text,
    priority integer,
    max_attempts integer
) AS $$
BEGIN
    IF function_definition_id IS NULL THEN
        RETURN;
    END IF;

    SELECT c.queue_name, c.priority, c.max_attempts
    INTO routing.queue_name,
         routing.priority,
         routing.max_attempts
    FROM catalog_private.functions c
    WHERE c.id = routing.function_definition_id
      AND c.database_id = routing.database_id;

    -- Only surface a routing row when the definition actually exists (a missing
    -- id leaves every column NULL — the caller wants defaults, not a NULL row).
    IF routing.queue_name IS NULL
       AND routing.priority IS NULL
       AND routing.max_attempts IS NULL THEN
        RETURN;
    END IF;

    RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;

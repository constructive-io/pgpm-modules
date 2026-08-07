-- Deploy schemas/function_resolution/procedures/frame_candidates to pg

-- requires: schemas/function_resolution/schema
-- requires: pgpm-app-scope:schemas/app_scope/procedures/frames

BEGIN;

-- frame_candidates: expand the ordered frames of one execution into the
-- (owner_scope, owner_key) probe candidates a typed catalog is keyed by,
-- most-specific first.
--
-- app_scope.frames stays the single source of truth for ordering (and
-- cycle/depth safety); this only performs the expansion every catalog probe
-- needs, so the capability resolvers never hand-order scopes:
--   * global frame (key_value NULL):  (scope, owner_key IS NULL)
--   * keyed frame:                    (scope, owner_key = key)   -- most specific
--                                then (scope, owner_key IS NULL) -- scope default
-- ord is a global ordinality across frames, so the lowest ord that matches wins
-- regardless of which frame database answered.
CREATE FUNCTION function_resolution.frame_candidates(
    database_id uuid,
    scope text,
    entity_id uuid DEFAULT NULL
) RETURNS TABLE (
    lookup_database_id uuid,
    owner_scope text,
    owner_key uuid,
    ord bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT f.lookup_database_id,
           f.scope,
           cand.owner_key,
           (f.ord * 2) + cand.off
    FROM app_scope.frames(
        frame_candidates.database_id,
        frame_candidates.scope,
        frame_candidates.entity_id
    ) WITH ORDINALITY AS f(scope, lookup_database_id, key_value, ord)
    CROSS JOIN LATERAL (
        VALUES (f.key_value, 0::bigint), (NULL::uuid, 1::bigint)
    ) AS cand(owner_key, off)
    -- Global frames carry no key: emit the NULL candidate once.
    WHERE cand.off = 0 OR f.key_value IS NOT NULL
    ORDER BY (f.ord * 2) + cand.off;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;

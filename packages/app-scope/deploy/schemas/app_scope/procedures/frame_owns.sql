-- Deploy schemas/app_scope/procedures/frame_owns to pg
-- requires: schemas/app_scope/schema
-- requires: schemas/app_scope/procedures/frames

BEGIN;

-- frame_owns: does an execution's frame chain contain the frame that owns a
-- given catalog row? One boolean over app_scope.frames, so a WRITE-path
-- ownership check can admit exactly what the READ path would have resolved.
--
-- A typed catalog row carries its owning frame as a triple:
--   (owner_scope, owner_key, owner_database_id)
-- written by catalog sync — a database-scope row is ('database', <database_id>),
-- a global-tier row is ('app' | 'platform', NULL) — and the row's home database
-- disambiguates the one physical relation that holds every database's rows.
-- This function answers whether that triple names one of the frames
-- app_scope.frames returns for the execution, using the SAME identity test
-- function_resolution.resolve probes the catalog with:
--
--   keyed frame:  owner_scope = f.scope AND owner_key = f.key_value
--                 AND owner_database_id = (owner_key at `database` scope,
--                                          f.lookup_database_id otherwise)
--   global frame: owner_scope = f.scope AND owner_key IS NULL
--                 AND owner_database_id = f.lookup_database_id
--
-- The chain is an ANCESTRY relation, never a visibility one: it runs from the
-- execution's own scope up through its database, then the platform database's
-- own chain to the global `platform` terminal. A peer — another tenant, another
-- keyed owner — is not on it and can never be admitted, which is why the
-- ownership question is expressed as "is this on my chain", not "may I see
-- this". Publication and visibility flags are not inputs here, exactly as they
-- are not inputs to the same-owner rule this arm sits beside.
--
-- No scope name is hardcoded, so a hierarchy that grows new levels needs no
-- change here: whatever app_scope.frames walks is what this admits.
CREATE FUNCTION app_scope.frame_owns(
    database_id uuid,
    scope text,
    entity_id uuid,
    owner_scope text,
    owner_key uuid,
    owner_database_id uuid
) RETURNS boolean AS $$
DECLARE
    v_owns boolean;
BEGIN
    -- A row whose owning frame is not fully identified cannot be proved to be
    -- on the chain, and an ownership check reports "not owned" rather than
    -- guessing. The execution's own database is equally required: the frame walk
    -- has no starting point without it.
    IF frame_owns.database_id IS NULL
       OR frame_owns.scope IS NULL
       OR frame_owns.owner_scope IS NULL
       OR frame_owns.owner_database_id IS NULL THEN
        RETURN false;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM app_scope.frames(
            frame_owns.database_id,
            frame_owns.scope,
            frame_owns.entity_id
        ) AS f(scope, lookup_database_id, key_value)
        WHERE f.scope = frame_owns.owner_scope
          AND (
                (
                    frame_owns.owner_key IS NOT NULL
                    AND f.key_value = frame_owns.owner_key
                    AND frame_owns.owner_database_id = CASE
                            WHEN frame_owns.owner_scope = 'database'
                                THEN frame_owns.owner_key
                            ELSE f.lookup_database_id
                        END
                )
                OR (
                    frame_owns.owner_key IS NULL
                    AND frame_owns.owner_database_id = f.lookup_database_id
                )
              )
    )
    INTO v_owns;

    RETURN v_owns;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION app_scope.frame_owns(uuid, text, uuid, text, uuid, uuid) IS
'True when the frame that owns a catalog row — its (owner_scope, owner_key, owner_database_id) triple — is one of the frames app_scope.frames returns for the given execution. The identity test is the one function_resolution.resolve probes the catalog with, so a write-path ownership guard admits exactly what the read path would resolve. The chain is ancestry, not visibility: the execution''s own scopes, its database, then the platform database''s chain — never a peer or another keyed owner. Returns false rather than raising when the row''s owning frame is not fully identified.';

COMMIT;

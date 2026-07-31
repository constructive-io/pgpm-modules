-- Deploy schemas/infra_utils/procedures/resource_installation_guards to pg

-- requires: schemas/infra_utils/schema
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

-- ============================================================================
-- Installation lifecycle guards
-- ============================================================================
-- `uninstall` keeps the installation row (and with it the merkle history) and
-- deletes only the member resources, so an installation has two shapes: live,
-- and a tombstone that can be installed again. The lifecycle functions express
-- that as a conditional read/write whose result is handed here so the caller
-- gets a named error instead of a silent no-op — the failure mode where
-- `upgrade` matched zero members and still reported success.

-- Called with the id of a LIVE installation of the same slug, or NULL when the
-- slug is free (never installed, or a tombstone that install revives).
CREATE FUNCTION infra_utils.assert_bundle_installable(
  installation_id uuid,
  bundle_slug text
) RETURNS void AS $$
BEGIN
  IF installation_id IS NOT NULL THEN
    PERFORM errors.raise_error(
      'RESOURCE_INSTALLATION_EXISTS',
      jsonb_build_object(
        'slug', bundle_slug,
        'reason', 'bundle is already installed — upgrade it, or uninstall it first'
      ),
      'public'
    );
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE FUNCTION infra_utils.assert_bundle_installed(
  installation_id uuid,
  target_installation_id uuid
) RETURNS void AS $$
BEGIN
  IF installation_id IS NULL THEN
    PERFORM errors.raise_error(
      'RESOURCE_INSTALLATION_NOT_INSTALLED',
      jsonb_build_object(
        'installation_id', target_installation_id,
        'reason', 'installation is uninstalled — install the bundle instead of upgrading it'
      ),
      'public'
    );
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMIT;

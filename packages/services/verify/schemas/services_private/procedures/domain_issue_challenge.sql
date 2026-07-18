-- Verify schemas/services_private/procedures/domain_issue_challenge

BEGIN;

SELECT has_function_privilege(
  'services_private.domain_issue_challenge(uuid, text, uuid)',
  'execute'
);

ROLLBACK;

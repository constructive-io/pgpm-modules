# @pgpm/errors

Canonical structured error raising for constructive-db.

Exposes a single hard-coded runtime helper, `errors.raise_error`, so every
application error is thrown in one consistent, machine-readable shape instead of
bare `RAISE EXCEPTION` strings.

```sql
PERFORM errors.raise_error(
  'ACCOUNT_EXISTS',
  jsonb_build_object('email', v_email),
  'public'
);
```

This raises an exception whose:

- **MESSAGE** is the bare code (`ACCOUNT_EXISTS`) — message-scanning clients keep working;
- **DETAIL** is a JSON payload `{ "code", "context", "class" }` — the machine-readable
  contract consumed by `@constructive-io/errors` on the server/client. Raw `context`
  values survive to the client untouched (no server-side English interpolation), which
  is what enables i18n on dynamic errors;
- **ERRCODE** is `P0001` (the semantic code rides in `DETAIL`, not SQLSTATE).

`class` is `'public'` (safe to show end users) or `'internal'` (developer/invariant
error, masked in production).

No dynamic SQL: this is a plain static function, not a generated one.

## Reserved codes: agent-auth session/principal chains

The session-chain and principal-delegation design
(constructive-planning #1971, schema foundation in #1972) reserves the following
codes. `mint_child_session` raises the first group today; the rest are claimed
here so the sibling features (token exchange, refresh rotation, child
principals) and the `@constructive-io/errors` registry mapping can land without a
naming collision. All are `'public'` class.

| Code | Raised by |
| --- | --- |
| `SESSION_CHAIN_EXPIRED` | `mint_child_session` — parent chain ceiling passed, or child TTL beyond it |
| `SESSION_DEPTH_EXCEEDED` | `mint_child_session` — `parent.depth + 1 > max_session_depth` |
| `SESSION_TTL_EXCEEDS_PARENT` | `mint_child_session` — child `expires_at > parent.expires_at` |
| `PRINCIPAL_EXPIRED` | `mint_child_session` — supplied principal past its `expires_at`; `create_child_principal` — parent principal past its `expires_at` |
| `PRINCIPAL_NOT_DESCENDANT` | `mint_child_session` — principal is not the parent credential's principal or a descendant of it; `create_child_principal` — a principal caller names a parent that is not itself or a descendant; `delete_principal` — a principal caller names a target outside its own descendant subtree |
| `SESSION_NOT_DESCENDANT` | cascade revoke (reserved) |
| `TOKEN_EXCHANGE_DISABLED` | `mint_access_token` — `auth_settings.allow_token_exchange` is off |
| `CREDENTIAL_NOT_EXCHANGEABLE` | `mint_access_token` — caller credential kind is not `api_key`/`access_token`/`bearer`/`cookie` |
| `PRINCIPAL_REQUIRED` | `mint_access_token` — a human session called without `principal_id` |
| `CREDENTIAL_NOT_EXTENDABLE` | `extend_token_expires` — caller credential kind is `access_token`/`refresh_token`; short-lived tokens only gain time through `refresh_access_token` |
| `REFRESH_TOKEN_INVALID` | `refresh_access_token` — unknown, expired or revoked token, or its session/chain is dead |
| `REFRESH_TOKEN_REUSED` | `refresh_access_token` — the token's session tree was killed by a replay (`revoked_reason = 'refresh_reuse'`); the replaying call itself revokes the tree, records `token.refresh_reused` and returns no tokens |
| `INTENT_TOO_LONG` | `mint_access_token` — `intent` longer than 512 characters |
| `PRINCIPAL_DELEGATION_DISABLED` | child principals (reserved) |
| `PRINCIPAL_DEPTH_EXCEEDED` | `create_child_principal` — `parent.depth + 1 > auth_settings.max_principal_depth` |
| `PRINCIPAL_CHILD_WIDENS` | `create_child_principal` — `allowed_mask` holds a bit the parent's derived SPRT lacks, or `entity_ids` names an entity outside the parent's `principal_entities`; `create_principal_from_preset` — an override widens the preset (capability name, scope, read-only off, flag on, delegation, entity_policy, TTL) |
| `PRINCIPAL_PRESET_INVALID_OVERRIDES` | `create_principal_from_preset` — `overrides` is not a JSON object or names an unknown `entity_policy` |
| `PRINCIPAL_PRESET_SCOPE_UNSUPPORTED` | `create_principal_from_preset` — the preset lists a membership scope the tenant did not provision |
| `PRINCIPAL_PRESET_ENTITIES_REQUIRED` | `create_principal_from_preset` — `entity_policy = require_list` and no `entity_ids` were given |
| `PRINCIPAL_PRESET_UNKNOWN_CAPABILITY` | `create_principal_from_preset` — a capability name in the preset (or override) is not in the tenant's capabilities catalog at that scope |
| `PRINCIPAL_CHILD_TTL_EXCEEDS_PARENT` | `create_child_principal` — `expires_at` is null or later than the parent principal, the current session, or the session chain |

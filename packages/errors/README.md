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

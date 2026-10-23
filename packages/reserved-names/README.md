# @pgpm/reserved-names

<p align="center" width="100%">
  <img height="250" src="https://raw.githubusercontent.com/constructive-io/constructive/refs/heads/main/assets/outline-logo.svg" />
</p>

<p align="center" width="100%">
  <a href="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml">
    <img height="20" src="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml/badge.svg" />
  </a>
   <a href="https://github.com/constructive-io/pgpm-modules/blob/main/LICENSE"><img height="20" src="https://img.shields.io/badge/license-MIT-blue.svg"/></a>
   <a href="https://www.npmjs.com/package/@pgpm/reserved-names"><img height="20" src="https://img.shields.io/github/package-json/v/constructive-io/pgpm-modules?filename=packages%2Freserved-names%2Fpackage.json"/></a>
</p>

Reserved names that nobody may claim — subdomains, usernames, slugs, or any other kind — kept as rows and checked live by one function.

## Overview

`@pgpm/reserved-names` keeps one shared list, as tables, and callers check it live at the moment someone claims a name. A new entry takes effect at once for every caller, with no regeneration or redeploy of the callers.

| table | what it holds |
| --- | --- |
| `reserved_names.kinds` | categories of name: `subdomain`, `username`, `domain`, `slug` (add more with a migration) |
| `reserved_names.reasons` | why a name is reserved: `platform`, `brand`, `lookalike`, `abuse` |
| `reserved_names.names` | the entries: `kind`, `name` (lowercase), `match` (`exact` / `prefix` / `suffix`), `reason` |

Every entry must point at a real kind and reason (foreign keys), so a typo cannot quietly create an empty category. The primary key is `(kind, name, match)`.

The starter data, in fixtures, is the four kinds and four reasons plus a `subdomain` list: hostnames a visitor would read as the platform's own under a shared domain (`login`, `admin`, `www`, `mail`, `ns1`, …), and a `xn--` prefix entry that blocks punycode lookalikes (`аpple` with a Cyrillic `а`). The other kinds start empty.

## Installation

```bash
pgpm install @pgpm/reserved-names
pgpm deploy
```

## Usage

```sql
SELECT reserved_names.is_reserved('subdomain', 'login');        -- true
SELECT reserved_names.is_reserved('subdomain', 'LOGIN');        -- true (case-insensitive)
SELECT reserved_names.is_reserved('subdomain', 'xn--pple-43d'); -- true (prefix entry)
SELECT reserved_names.is_reserved('subdomain', 'mystore');      -- false
SELECT reserved_names.is_reserved('username', 'login');         -- false (kinds are separate)

SELECT name, match, reason FROM reserved_names.reserved_by('subdomain', 'xn--pple-43d');
--  xn-- | prefix | lookalike
```

- `is_reserved(kind, name) RETURNS boolean`: true when any entry matches.
- `reserved_by(kind, name) RETURNS SETOF reserved_names.names`: the matching entries, so an error can say why.

Both are `STABLE` SQL, lowercase `kind` and `name` before comparing, and treat `NULL` as not reserved. Matching:

- `exact`: the name itself.
- `prefix`: every name starting with it (`xn--`, `staff-`).
- `suffix`: every name ending with it. `.example.com` blocks `shop.example.com`, but not `example.com` itself (add an `exact` entry for that) and not `notexample.com`.

### Adding names

The list changes only through migrations. Add a pgpm fixture change that inserts rows:

```sql
INSERT INTO reserved_names.names (kind, name, match, reason) VALUES
  ('subdomain', 'www2', 'exact', 'platform'),
  ('subdomain', 'staff-', 'prefix', 'platform'),
  ('domain', '.example.com', 'suffix', 'brand'),
  ('username', 'support', 'exact', 'platform');
```

A new category or reason is a row in `kinds` or `reasons` first.

## Access

Everyone can read the three tables and call both functions, so a UI can say "that name is reserved" before submitting. The list is public, so there is no row-level security. No role is granted `INSERT`, `UPDATE` or `DELETE`: only the owner (migrations, or a `SECURITY DEFINER` function it owns) can change it.

## Testing

```bash
pnpm test
```

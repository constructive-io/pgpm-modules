# @pgpm/ltree-helpers

<p align="center" width="100%">
  <img height="250" src="https://raw.githubusercontent.com/constructive-io/constructive/refs/heads/main/assets/outline-logo.svg" />
</p>

<p align="center" width="100%">
  <a href="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml">
    <img height="20" src="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml/badge.svg" />
  </a>
   <a href="https://github.com/constructive-io/pgpm-modules/blob/main/LICENSE"><img height="20" src="https://img.shields.io/badge/license-MIT-blue.svg"/></a>
   <a href="https://www.npmjs.com/package/@pgpm/ltree-helpers"><img height="20" src="https://img.shields.io/github/package-json/v/constructive-io/pgpm-modules?filename=packages%2Fltree-helpers%2Fpackage.json"/></a>
</p>

Slash-path to ltree/lquery conversion helpers for PostgreSQL.

## Overview

`@pgpm/ltree-helpers` provides simple SQL functions for converting between user-facing slash-delimited paths (like `/projects/alpha/docs`) and PostgreSQL's `ltree`/`lquery` types. This keeps ltree as an implementation detail while exposing a familiar filesystem-style path API.

## Features

- **Slash to ltree**: Convert `/projects/alpha/docs` to `projects.alpha.docs`
- **ltree to slash**: Convert `projects.alpha.docs` to `/projects/alpha/docs`
- **Glob to lquery**: Convert `/projects/*/docs` to `projects.*.docs` and `/**` to `.*{1,}`
- **Pure SQL**: All functions are `IMMUTABLE STRICT` for maximum performance and plan caching
- **Own schema**: Functions live in the `ltree_helpers` schema, not in `public`

## Installation

```bash
cd packages/my-module
pgpm install @pgpm/ltree-helpers
```

## Usage

```sql
-- Slash path to ltree
SELECT ltree_helpers.to_path('/projects/alpha/docs');
-- => 'projects.alpha.docs'::ltree

-- ltree to slash path
SELECT ltree_helpers.to_slash('projects.alpha.docs'::ltree);
-- => '/projects/alpha/docs'

-- Glob to lquery (single-level wildcard)
SELECT ltree_helpers.to_query('/projects/*/docs');
-- => 'projects.*.docs'::lquery

-- Glob to lquery (recursive wildcard)
SELECT ltree_helpers.to_query('/projects/**');
-- => 'projects.*{1,}'::lquery

-- Use with ltree operators
SELECT * FROM files
WHERE path <@ ltree_helpers.to_path('/projects/alpha');

-- Glob matching
SELECT * FROM files
WHERE path ~ ltree_helpers.to_query('/projects/*/docs');
```

## API

| Function | Signature | Description |
|----------|-----------|-------------|
| `ltree_helpers.to_path` | `(text) -> ltree` | Slash path to ltree |
| `ltree_helpers.to_slash` | `(ltree) -> text` | ltree to slash path |
| `ltree_helpers.to_query` | `(text) -> lquery` | Glob pattern to lquery |

## Dependencies

- `ltree` (PostgreSQL contrib extension)
- `pgpm-verify`

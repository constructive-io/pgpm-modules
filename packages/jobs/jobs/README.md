# @pgpm/jobs

Core job system for background task processing in PostgreSQL.

## Overview

`@pgpm/jobs` provides the core abstractions and interfaces for a PostgreSQL-based background job processing system. This package defines the schema, tables, and procedures for job queue management, scheduled jobs, and worker coordination. It serves as the foundation for building reliable background task processing systems entirely within PostgreSQL.

## Features

- **Job Queue Schema**: Core `app_jobs` schema with jobs, scheduled_jobs, and job_queues tables
- **Job Management Procedures**: Functions for adding, retrieving, completing, and failing jobs
- **Scheduled Jobs**: Support for cron-style and rule-based job scheduling
- **Worker Coordination**: Job locking and worker management with expiry
- **Priority Queue**: Process jobs by priority, run time, and insertion order
- **Automatic Retries**: Configurable retry attempts with failure tracking
- **Job Keys**: Upsert semantics for idempotent job creation
- **Trigger Functions**: Automatic job creation from table changes

## Installation

### Prerequisites

```bash
# Install pgpm globally
npm install -g pgpm

# Start PostgreSQL
pgpm docker start

# Set environment variables
eval "$(pgpm env)"
```

### Deploy

#### Option 1: Deploy from Package Directory

```bash
cd packages/jobs/jobs
pgpm deploy --createdb
```

#### Option 2: Deploy from Workspace Root

```bash
# Install workspace dependencies
pgpm install

# Deploy with dependencies
pgpm deploy <database_name> --yes --recursive --createdb
```

## Core Schema

The `app_jobs` schema provides three main tables:

### jobs Table
Stores active jobs awaiting processing:
- `id`: Unique job identifier
- `database_id`: Database/tenant identifier
- `task_identifier`: Job type/handler name
- `payload`: JSON data for the job
- `priority`: Lower numbers = higher priority
- `run_at`: Scheduled execution time
- `attempts`: Current attempt count
- `max_attempts`: Maximum retry attempts
- `locked_by`: Worker ID holding the lock
- `locked_at`: Lock timestamp
- `key`: Optional unique key for upsert

### scheduled_jobs Table
Stores recurring job definitions:
- `id`: Unique identifier
- `database_id`: Database/tenant identifier
- `task_identifier`: Job type/handler name
- `payload`: JSON data template
- `schedule_info`: Cron or rule-based schedule
- `priority`: Job priority
- `max_attempts`: Maximum retries

### job_queues Table
Tracks queue statistics and locking:
- `queue_name`: Queue identifier
- `job_count`: Number of jobs in queue
- `locked_by`: Worker ID holding queue lock
- `locked_at`: Lock timestamp

## Usage

### Adding Jobs

```sql
-- Add a simple job
SELECT app_jobs.add_job(
  db_id := '5b720132-17d5-424d-9bcb-ee7b17c13d43'::uuid,
  identifier := 'send_email',
  payload := '{"to": "user@example.com"}'::json
);

-- Add a delayed job with priority
SELECT app_jobs.add_job(
  db_id := '5b720132-17d5-424d-9bcb-ee7b17c13d43'::uuid,
  identifier := 'generate_report',
  payload := '{"report_id": 123}'::json,
  run_at := now() + interval '1 hour',
  priority := 10
);
```

### Retrieving Jobs

```sql
-- Worker fetches next job
SELECT * FROM app_jobs.get_job(
  worker_id := 'worker-1',
  task_identifiers := ARRAY['send_email', 'generate_report']
);
```

### Completing Jobs

```sql
-- Mark job as successfully completed
SELECT app_jobs.complete_job(
  worker_id := 'worker-1',
  job_id := 123
);
```

### Failing Jobs

```sql
-- Mark job as failed (will retry if attempts remain)
SELECT app_jobs.fail_job(
  worker_id := 'worker-1',
  job_id := 123,
  error_message := 'Connection timeout'
);
```

### Scheduled Jobs

```sql
-- Create a scheduled job
INSERT INTO app_jobs.scheduled_jobs (
  database_id,
  task_identifier,
  schedule_info
) VALUES (
  '5b720132-17d5-424d-9bcb-ee7b17c13d43'::uuid,
  'cleanup_task',
  '{"hour": [2], "minute": [0]}'::json
);

-- Execute a scheduled job
SELECT * FROM app_jobs.run_scheduled_job(1);
```

## Trigger Functions

The package includes trigger functions for automatic job creation:

### tg_add_job_with_row_id
Creates a job when a row is inserted, using the row's ID in the payload.

```sql
CREATE TRIGGER auto_process
AFTER INSERT ON my_table
FOR EACH ROW
EXECUTE FUNCTION app_jobs.tg_add_job_with_row_id(
  'database-uuid',
  'process_record',
  'id'
);
```

### tg_add_job_with_row
Creates a job with the entire row as JSON payload.

```sql
CREATE TRIGGER auto_process
AFTER INSERT ON my_table
FOR EACH ROW
EXECUTE FUNCTION app_jobs.tg_add_job_with_row(
  'database-uuid',
  'process_record'
);
```

### tg_add_job_with_fields
Creates a job with specific fields from the row.

```sql
CREATE TRIGGER auto_process
AFTER INSERT ON my_table
FOR EACH ROW
EXECUTE FUNCTION app_jobs.tg_add_job_with_fields(
  'database-uuid',
  'process_record',
  'field1',
  'field2',
  'field3'
);
```

## Functions Reference

### app_jobs.add_job(...)
Adds a new job to the queue.

**Parameters:**
- `db_id` (uuid): Database identifier
- `identifier` (text): Job type
- `payload` (json): Job data
- `job_key` (text): Optional unique key
- `queue_name` (text): Optional queue name
- `run_at` (timestamptz): Execution time
- `max_attempts` (integer): Max retries
- `priority` (integer): Job priority

### app_jobs.get_job(...)
Retrieves and locks the next available job.

**Parameters:**
- `worker_id` (text): Worker identifier
- `task_identifiers` (text[]): Job types to fetch
- `job_expiry` (interval): Lock expiry duration

### app_jobs.complete_job(...)
Marks a job as completed.

**Parameters:**
- `worker_id` (text): Worker identifier
- `job_id` (bigint): Job identifier

### app_jobs.fail_job(...)
Marks a job as failed.

**Parameters:**
- `worker_id` (text): Worker identifier
- `job_id` (bigint): Job identifier
- `error_message` (text): Error description

### app_jobs.add_scheduled_job(...)
Creates a scheduled job.

**Parameters:**
- `db_id` (uuid): Database identifier
- `identifier` (text): Job type
- `payload` (json): Job data
- `schedule_info` (json): Schedule configuration
- Additional optional parameters

### app_jobs.run_scheduled_job(...)
Executes a scheduled job.

**Parameters:**
- `scheduled_job_id` (bigint): Scheduled job identifier

## Dependencies

- `@pgpm/default-roles`: Role-based access control
- `@pgpm/verify`: Verification utilities

## Testing

```bash
pnpm test
```

## Development

See the [Development](#development) section below for information on working with this package.

---

## Development

### **Before You Begin**

```bash
# 1. Install pgpm
npm install -g pgpm

# 2. Start Postgres (Docker or local)
pgpm docker start

# 3. Load PG* environment variables (PGHOST, PGUSER, ...)
eval "$(pgpm env)"
```

---

### **Starting a New Project**

```bash
# 1. Create a workspace
pgpm init --workspace
cd my-app

# 2. Create your first module
pgpm init

# 3. Add a migration
pgpm add some_change

# 4. Deploy (auto-creates database)
pgpm deploy --createdb
```

---

### **Working With an Existing Project**

```bash
# 1. Clone and enter the project
git clone <repo> && cd <project>

# 2. Install dependencies
pgpm install

# 3. Deploy locally
pgpm deploy --createdb
```

---

### **Testing a Module Inside a Workspace**

```bash
# 1. Install workspace deps
pgpm install

# 2. Enter the module directory
cd packages/<some-module>

# 3. Run tests in watch mode
pnpm test:watch
```

## Related Tooling

* [pgpm](https://github.com/launchql/launchql/tree/main/packages/pgpm): **🖥️ PostgreSQL Package Manager** for modular Postgres development. Works with database workspaces, scaffolding, migrations, seeding, and installing database packages.
* [pgsql-test](https://github.com/launchql/launchql/tree/main/packages/pgsql-test): **📊 Isolated testing environments** with per-test transaction rollbacks—ideal for integration tests, complex migrations, and RLS simulation.
* [supabase-test](https://github.com/launchql/launchql/tree/main/packages/supabase-test): **🧪 Supabase-native test harness** preconfigured for the local Supabase stack—per-test rollbacks, JWT/role context helpers, and CI/GitHub Actions ready.
* [graphile-test](https://github.com/launchql/launchql/tree/main/packages/graphile-test): **🔐 Authentication mocking** for Graphile-focused test helpers and emulating row-level security contexts.
* [pgsql-parser](https://github.com/launchql/pgsql-parser): **🔄 SQL conversion engine** that interprets and converts PostgreSQL syntax.
* [libpg-query-node](https://github.com/launchql/libpg-query-node): **🌉 Node.js bindings** for `libpg_query`, converting SQL into parse trees.
* [pg-proto-parser](https://github.com/launchql/pg-proto-parser): **📦 Protobuf parser** for parsing PostgreSQL Protocol Buffers definitions to generate TypeScript interfaces, utility functions, and JSON mappings for enums.

## Disclaimer

AS DESCRIBED IN THE LICENSES, THE SOFTWARE IS PROVIDED "AS IS", AT YOUR OWN RISK, AND WITHOUT WARRANTIES OF ANY KIND.

No developer or entity involved in creating this software will be liable for any claims or damages whatsoever associated with your use, inability to use, or your interaction with other users of the code, including any direct, indirect, incidental, special, exemplary, punitive or consequential damages, or loss of profits, cryptocurrencies, tokens, or anything else of value.

# @pgpm/faker

create fake data in PostgreSQL

## Overview

`@pgpm/faker` provides a comprehensive set of fake data generation functions directly in PostgreSQL. Perfect for seeding test databases, creating demo data, and development environments. All functions are implemented in pure plpgsql and return realistic-looking data without external dependencies.

## Features

- **Geographic Data**: Latitude/longitude coordinates, addresses by state
- **Text Generation**: Sentences, paragraphs, tags, names
- **Temporal Data**: Random timestamps, dates, intervals
- **Numeric Data**: Random integers and floats
- **Contact Information**: Email, phone, IP addresses
- **File & Media**: URLs, images, profile pictures, attachments
- **Business Data**: Company names, usernames, tokens
- **State-Aware**: Filter data by US state codes
- **Pure plpgsql**: No external dependencies required

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
cd packages/utils/faker
pgpm deploy --createdb
```

#### Option 2: Deploy from Workspace Root

```bash
# Install workspace dependencies
pgpm install

# Deploy with dependencies
pgpm deploy mydb1 --yes --createdb
```

## Usage

## state, city, zip

```sql
select faker.state();
-- CA

select faker.city();
-- Belle Haven

select faker.city('MI');
-- Livonia

select faker.zip();
-- 48105

select faker.zip('Los Angeles');
-- 90272
```

## address, street

```sql
select faker.address();
-- 762 MESA ST         
-- Fort Mohave, AZ 86427

select faker.address('MI');
-- 2316 LAPHAM WAY           
-- Sterling Heights, MI 48312

select faker.street();
-- CLAY ST
```

## tags

Tags can be seeded in `faker.dictionary` table, here's an example with sustainability 

```sql
select faker.tags();
-- {"causes of global warming","electronic waste","solar powered cars"}
```

## words

```sql
select faker.word();
-- woodpecker
```

Specify word types

```sql
select faker.word(ARRAY['adjectives']);
-- decisive
```

## paragraphs

```sql
select faker.paragraph();
-- Ligula. Aliquet torquent consequat egestas dui. Nullam sed tincidunt mauris porttitor ad taciti rutrum eleifend. Phasellus.
```

## email

```sql
select faker.email();
-- crimson79@hotmail.com
```

## uuid

```sql
select faker.uuid();
-- 327cb21d-1680-47ee-9979-3689e1bcb9ab
```

## tokens, passwords

```sql
select faker.token();
-- 9e23040a7825529beb1528c957eac73f

select faker.token(20);
-- 7504ef4eafbba04a9645198b10ebc9616afce13a

select faker.password();
-- d8f1cca306e4d7^15bb(62618c1e
```

## hostname

```sql
select faker.hostname();
-- fine.net
```

## time unit

```sql
select faker.time_unit();
-- hour
```

## float

```sql
select faker.float();
-- 64.6970694223782

select faker.float(2.3,10.5);
-- 10.233102884792025
```

## integer

```sql
select faker.integer();
-- 8

select faker.integer(2,10);
-- 7
```

## date

```sql
select faker.date();
-- 2020-10-02
```

Date 1-3 days ago

```sql
select faker.date(1,3);
-- 2020-12-02
```

Date in the future between 1-3 days

```sql
select faker.date(1,3, true);
-- 2020-12-06
```

## birthdate

```sql
select faker.birthdate();
-- 2007-02-24
```

Generate birthdate for somebody who is between age of 37 and 64

```sql
select faker.birthdate(37, 64);
-- 1972-08-10
```

## interval

```sql
select faker.interval();
-- 00:01:34.959831
```

Generate an interval between 2 and 300 seconds

```sql
select faker.interval(2,300);
-- 00:01:04
```

## gender

```sql
select faker.gender();
-- F

select faker.gender();
-- M
```

## boolean

```sql
select faker.boolean();
-- TRUE
```

## timestamptz

```sql
select faker.timestamptz();
-- 2019-12-20 15:57:29.520365+00
```

Future timestamptz

```sql
select faker.timestamptz(TRUE);
-- 2020-12-03 23:00:10.013301+00
-- 
```

## mime types

```sql
select faker.mime();
-- text/x-scss
```

## file extensions

```sql
select faker.ext();
-- html
```

Specify a mimetype

```sql
select faker.ext('image/png');
-- png
```

Image mimetypes

```sql
select faker.image_mime();
-- image/gif
```

## image

```sql
select faker.image();
-- {"url": "https://picsum.photos/843/874", "mime": "image/gif"}
```

## profilepic

credit: thank you https://randomuser.me 

```sql
select faker.profilepic();
-- {"url": "https://randomuser.me/api/portraits/women/53.jpg", "mime": "image/jpeg"}
```

Specify a gender

```sql
select faker.profilepic('M');
-- {"url": "https://randomuser.me/api/portraits/men/4.jpg", "mime": "image/jpeg"}
```

## file

```sql
select faker.file();
-- scarlet.jpg
```

Specify a mimetype

```sql
select faker.file('image/png');
-- anaconda.png
```

## url

```sql
select faker.url();
-- https://australian.io/copper.gzip
```

## upload

```sql
select faker.upload();
-- https://magenta.co/moccasin.yaml
```

## attachment

```sql
select faker.attachment();
--  {"url": "https://silver.io/sapphire.jsx", "mime": "text/jsx"}
```

## phone

```sql
select faker.phone();
-- +1 (121) 617-3329
```

## ip

```sql
select faker.ip();
-- 42.122.9.119
```

## username

```sql
select faker.username();
-- amaranth28
```

## name

```sql
select faker.name();
-- Lindsay
```

Specify a gender

```sql
select faker.name('M');
-- Stuart

select faker.name('F');
-- Shelly
```

## surname

```sql
select faker.surname();
-- Smith
```

## fullname

```sql
select faker.fullname();
-- Ross Silva

select faker.fullname('M');
-- George Spencer
```

## business

```sql
select faker.business();
-- Seed Partners, Co.
```

## longitude / latitude coordinates

```sql
select faker.lnglat( -118.561721, 33.59, -117.646374, 34.23302 );
-- (-118.33162189532844,34.15614699957491)

select faker.lnglat();
-- (-74.0205,40.316)
```

## Use Cases

### Seeding Test Databases

Generate realistic test data for development:

```sql
-- Create test users with fake data
INSERT INTO users (name, email, created_at)
SELECT 
  faker.fullname(),
  faker.email(),
  faker.timestamptz()
FROM generate_series(1, 100);
```

### Geographic Testing

Test location-based features:

```sql
-- Create test locations with coordinates
INSERT INTO locations (lat, lng, address)
SELECT 
  (faker.lnglat()).lat,
  (faker.lnglat()).lng,
  faker.address()
FROM generate_series(1, 50);
```

### Content Generation

Generate fake content for testing:

```sql
-- Create blog posts
INSERT INTO posts (title, content, tags, published_at)
SELECT 
  faker.word() || ' ' || faker.word(),
  faker.paragraph(),
  faker.tags(),
  faker.timestamptz()
FROM generate_series(1, 100);
```

### Demo Data

Create realistic demo data for presentations:

```sql
-- E-commerce orders
INSERT INTO orders (customer_name, phone, total, order_date)
SELECT 
  faker.fullname(),
  faker.phone(),
  faker.float(10, 1000),
  faker.date()
FROM generate_series(1, 1000);
```

## Testing

```bash
pnpm test
```

## Dependencies

None - this is a pure plpgsql implementation.

---

## Development

## start the postgres db process

First you'll want to start the postgres docker (you can also just use `docker-compose up -d`):

```sh
make up
```

## install modules

Install modules

```sh
yarn install
```

## install the Postgres extensions

Now that the postgres process is running, install the extensions:

```sh
make install
```

This basically `ssh`s into the postgres instance with the `packages/` folder mounted as a volume, and installs the bundled sql code as pgxn extensions.

## testing

Testing will load all your latest sql changes and create fresh, populated databases for each sqitch module in `packages/`.

```sh
yarn test:watch
```

## building new modules

Create a new folder in `packages/`

```sh
pgpm init
```

Then, run a generator:

```sh
pgpm generate
```

You can also add arguments if you already know what you want to do:

```sh
pgpm generate schema --schema myschema
pgpm generate table --schema myschema --table mytable
```

## deploy code as extensions

`cd` into `packages/<module>`, and run `pgpm package`. This will make an sql file in `packages/<module>/sql/` used for `CREATE EXTENSION` calls to install your sqitch module as an extension.

## recursive deploy

You can also deploy all modules utilizing versioning as sqtich modules. Remove `--createdb` if you already created your db:

```sh
pgpm deploy mydb1 --yes --createdb
```

---

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
pnpm install

# 3. Deploy locally
pgpm deploy --createdb
```

---

### **Testing a Module Inside a Workspace**

```bash
# 1. Install workspace deps
pnpm install

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

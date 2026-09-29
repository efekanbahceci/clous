# Clous

Next-generation Backend-as-a-Service (BaaS) and type-safe ORM platform. Clous takes a single declarative schema written in TypeScript and compiles it into PostgreSQL DDL with native Row Level Security (RLS), end-to-end TypeScript definitions, and an OpenAPI 3.0 specification.

---

## Architecture Overview

Clous is engineered as a modular monorepo separating schema compilation, developer tooling, and runtime execution:

```
clous/
├── packages/
│   ├── core/           # Compiler engine (AST, Builder, SQL/TS/OpenAPI Emitters)
│   ├── server/         # Dynamic Fastify runtime engine with RLS session injection
│   └── cli/            # Developer toolchain (offline code generation & auth sync)
├── examples/
│   ├── basic/          # Compiler pipeline example
│   └── server-demo/    # Live Fastify runtime CRUD server demo
├── ARCHITECTURE.md     # In-depth architectural design specification
└── package.json        # Workspace configuration
```

### Packages

| Package | Version | Status | Description |
|---|---|---|---|
| `@clous/core` | 1.0.1 | Published | Core compiler engine, Intermediate Representation (IR), and emitters. |
| `@clous/cli` | 0.1.0 | Published | Developer CLI for local code generation, watching, and cloud sync. |
| `@clous/server` | 0.1.0 | Internal | Dynamic CRUD runtime engine mounting endpoints directly from AST. |

---

## The Compilation Pipeline

Clous treats your TypeScript schema as the single source of truth. Every layer of your backend infrastructure is derived synchronously without manual drift:

```
                        +----------------------+
                        |      schema.ts       |
                        | (Declarative Schema) |
                        +----------+-----------+
                                   |
                                   v
                        +----------------------+
                        |   Semantic Parser    |
                        |   & AST Validation   |
                        +----------+-----------+
                                   |
            +----------------------+----------------------+
            |                      |                      |
            v                      v                      v
+-----------------------+ +------------------+ +---------------------+
|  PostgresSqlEmitter   | |   DtsEmitter     | |   OpenApiEmitter    |
| (Tables, Indexes, RLS)| | (.d.ts Types)    | | (OpenAPI 3.0 Spec)  |
+-----------------------+ +------------------+ +---------------------+
```

1. **Semantic Validation:** Table names, column types, and foreign key references are validated at build time. Foreign keys pointing to non-existent tables or invalid types halt execution with explicit diagnostics.
2. **PostgreSQL DDL Generation:** Emits standard SQL including `CREATE TABLE`, constraints, composite indexes, and PostgreSQL `CREATE POLICY` statements. It automatically deploys `auth.uid()` and `auth.role()` functions backed by per-request session variables.
3. **Type Definitions:** Emits TypeScript definitions (`Row`, `Insert`, `Update`, `Database`). Generated interfaces distinguish between required columns, nullable columns, and optional defaults.
4. **OpenAPI 3.0 Specification:** Produces a structured specification for REST endpoints, pagination parameters, and request/response schemas.

---

## Getting Started

### 1. Installation

Install the CLI globally or as a project devDependency:

```bash
npm install -g @clous/cli
# or inside a local project:
npm install -D @clous/cli @clous/core
```

Node.js 20 or higher is required.

### 2. Initialize a Project

Scaffold a starter schema in your current directory:

```bash
clous init
```

This creates a `schema.ts` file and initializes a `.clous/` project configuration directory.

### 3. Define Your Data Model

Define your tables, relations, and security policies declaratively:

```typescript
import {
  schema,
  table,
  uuid,
  text,
  integer,
  boolean,
  timestamp,
} from '@clous/core';

// 1. Users Table with Row Level Security
export const users = table('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: text('email').unique().notNull(),
  fullName: text('full_name').notNull(),
  role: text('role').notNull().default('user'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})
  .policy('users_read_all', {
    for: 'select',
    using: 'true',
  })
  .policy('users_update_own', {
    for: 'update',
    to: 'authenticated',
    using: 'auth.uid() = id',
    withCheck: 'auth.uid() = id',
  });

// 2. Posts Table with Foreign Key Cascading
export const posts = table('posts', {
  id: uuid('id').primaryKey().defaultRandom(),
  title: text('title').notNull(),
  content: text('content').notNull(),
  likes: integer('likes').notNull().default(0),
  published: boolean('is_published').notNull().default(false),
  authorId: uuid('author_id')
    .notNull()
    .references('users', 'id', { onDelete: 'cascade' }),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})
  .index(['author_id'])
  .policy('posts_public_read', {
    for: 'select',
    using: 'is_published = true',
  });

// 3. Compile and Export Schema
export const appSchema = schema({
  version: '1.0.0',
  tables: [users, posts],
});

export default appSchema;
```

### 4. Compile the Schema

Compile the schema into SQL DDL, TypeScript definitions, and an OpenAPI specification:

```bash
clous generate
```

Output files are written to `./generated/`:
* `generated/schema.sql` (PostgreSQL DDL with RLS)
* `generated/db-types.d.ts` (TypeScript interfaces)
* `generated/openapi.json` (OpenAPI 3.0 specification)

---

## CLI Reference

The `@clous/cli` package separates offline developer operations from cloud synchronization commands:

### Local Commands (Offline / No Account Required)

These commands run completely offline without external network calls:

| Command | Description |
|---|---|
| `clous init` | Initialize a new Clous project with a starter schema |
| `clous generate` | Compile schema into SQL DDL, TypeScript types, and OpenAPI spec |
| `clous validate` | Run compile-time integrity checks on schema relations and syntax |
| `clous dev` | Watch `schema.ts` and recompile automatically on save |

### Cloud Commands (Web Panel & Control Plane Synchronization)

These commands connect your local workspace to the Clous Web Panel:

| Command | Description |
|---|---|
| `clous login` | Authenticate CLI via local callback listener or access token |
| `clous whoami` | Inspect the currently authenticated profile and active API URL |
| `clous link` | Link current workspace directory to a remote project ID |
| `clous status` | Inspect local schema status, linked project, and auth state |
| `clous logout` | Remove stored access credentials from local machine |

### CLI Options

```
-s, --schema <path>     Path to schema file (default: schema.ts)
-o, --out <dir>         Output directory for generated files (default: generated)
-t, --token <token>     Personal access token for headless CI/CD authentication
-p, --project-id <id>   Project ID for linking
-f, --force             Overwrite existing files without prompting
-h, --help              Display help information
-v, --version           Display CLI version
```

---

## Runtime Engine (`@clous/server`)

The runtime engine takes a compiled `SchemaNode` AST and spins up a fully functional, production-ready Fastify server with dynamic CRUD routes, JWT authentication, and automatic RLS context propagation:

```typescript
import { createClousServer } from '@clous/server';
import { appSchema } from './schema.js';

const server = await createClousServer({
  schema: appSchema,
  db: {
    connectionString: process.env.DATABASE_URL,
  },
  auth: {
    jwtSecret: process.env.JWT_SECRET,
    required: false,
  },
  server: {
    port: 3000,
    host: '0.0.0.0',
  },
});

await server.start();
```

### Endpoints Mounted Automatically

For each table in your schema:
* `GET /api/:table` - List records with pagination (`?page=1&limit=20`), sorting (`?sort=created_at&order=desc`), column selection (`?select=id,title`), and equality filters (`?published=true`).
* `GET /api/:table/:id` - Retrieve a single record by primary key.
* `POST /api/:table` - Create record with payload validation against required columns.
* `PATCH /api/:table/:id` - Update record (prevents updating primary keys).
* `DELETE /api/:table/:id` - Delete record.

System and documentation endpoints:
* `GET /api/_clous/health` - Server and database connection health check.
* `GET /api/_clous/schema` - Active schema AST JSON.
* `GET /api/_clous/openapi.json` - Real-time OpenAPI 3.0 specification.
* `GET /api/_clous/docs` - Interactive Scalar API documentation playground.

### Transactional RLS Session Injection

When querying PostgreSQL via `PgExecutor`, each request is executed within a database transaction. The user's JWT claims (`sub`, `role`, `email`) are injected using PostgreSQL session variables:

```sql
BEGIN;
SELECT
  set_config('request.jwt.claim.sub', $1, true),
  set_config('request.jwt.claim.role', $2, true),
  set_config('request.jwt.claim.email', $3, true);
-- Queries run here automatically evaluate CREATE POLICY rules
COMMIT;
```

This guarantees thread-safe, request-scoped Row Level Security without connection pool contamination.

---

## Column Types & Modifiers

### Supported Column Types

| Function | PostgreSQL Type | TypeScript Row Type |
|---|---|---|
| `uuid(name)` | `UUID` | `string` |
| `text(name)` | `TEXT` | `string` |
| `varchar(name, length?)` | `VARCHAR(n)` | `string` |
| `integer(name)` | `INTEGER` | `number` |
| `bigint(name)` | `BIGINT` | `string` |
| `boolean(name)` | `BOOLEAN` | `boolean` |
| `timestamp(name)` | `TIMESTAMP WITHOUT TIME ZONE` | `string \| Date` |
| `timestamptz(name)` | `TIMESTAMP WITH TIME ZONE` | `string \| Date` |
| `jsonb(name)` | `JSONB` | `any` |
| `float(name)` | `DOUBLE PRECISION` | `number` |
| `serial(name)` | `SERIAL` | `number` |

### Column Modifiers

```typescript
text('title')
  .primaryKey()                                             // PRIMARY KEY constraint
  .notNull()                                                // NOT NULL constraint
  .nullable()                                               // Allow NULL
  .unique()                                                 // UNIQUE constraint
  .default('Draft')                                         // Default scalar value
  .defaultNow()                                             // DEFAULT now()
  .defaultRandom()                                          // DEFAULT gen_random_uuid()
  .references('users', 'id', { onDelete: 'cascade' })       // Foreign key reference
```

---


---

## License

MIT © [Efekan Bahçeci](https://github.com/efekanbahceci)

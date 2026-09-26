# @clous/core

A schema compiler for backend infrastructure. You define your data model once in TypeScript. Clous converts it into PostgreSQL DDL, TypeScript type definitions, and an OpenAPI specification.

No runtime dependencies beyond `zod`. No external services. No API keys.

---

## Installation

```bash
npm install @clous/core
```

Node.js 20 or higher is required.

---

## How It Works

You write a schema. Clous compiles it. You take the output and use it however you want.

```
schema.ts  →  @clous/core  →  schema.sql       (run against your PostgreSQL database)
                           →  db-types.d.ts    (import into your project for type safety)
                           →  openapi.json     (import into Postman, Swagger UI, etc.)
```

---

## Step 1 — Define Your Schema

Create a file called `schema.ts` in your project:

```typescript
import { schema, table, uuid, text, integer, boolean, timestamp } from '@clous/core';

const users = table('users', {
  id:        uuid('id').primaryKey().defaultRandom(),
  email:     text('email').unique().notNull(),
  name:      text('name').notNull(),
  role:      text('role').notNull().default('user'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
});

const posts = table('posts', {
  id:        uuid('id').primaryKey().defaultRandom(),
  title:     text('title').notNull(),
  likes:     integer('likes').notNull().default(0),
  published: boolean('is_published').notNull().default(false),
  authorId:  uuid('author_id')
               .notNull()
               .references('users', 'id', { onDelete: 'cascade' }),
})
  .index(['author_id']);

export const appSchema = schema({
  tables: [users, posts],
});
```

`schema()` validates the structure immediately. If you reference a foreign key that does not exist, or use a duplicate table name, it throws a descriptive error at compile time — not at runtime.

---

## Step 2 — Generate Output

Create a file called `generate.ts`:

```typescript
import { PostgresSqlEmitter, DtsEmitter, OpenApiEmitter } from '@clous/core';
import { appSchema } from './schema.js';
import fs from 'node:fs';

// 1. PostgreSQL DDL
const sqlEmitter = new PostgresSqlEmitter();
const sql = sqlEmitter.emit(appSchema);
fs.mkdirSync('./generated', { recursive: true });
fs.writeFileSync('./generated/schema.sql', sql);

// 2. TypeScript type definitions
const dtsEmitter = new DtsEmitter();
await dtsEmitter.writeToFile('./generated/db-types.d.ts', appSchema);

// 3. OpenAPI 3.0 specification
const openApiEmitter = new OpenApiEmitter();
const spec = openApiEmitter.emit(appSchema, {
  title: 'My API',
  serverUrl: 'https://api.example.com',
});
fs.writeFileSync('./generated/openapi.json', JSON.stringify(spec, null, 2));
```

Run it:

```bash
npx tsx generate.ts
```

You now have three files in `./generated/`.

---

## Step 3 — Use the Output

**Apply the SQL to your database:**

```bash
psql -d your_database_name < ./generated/schema.sql
```

**Use the TypeScript types in your code:**

```typescript
import type { UsersRow, UsersInsert } from './generated/db-types.js';

// The type tells you exactly which fields are required
const newUser: UsersInsert = {
  email: 'ali@example.com',
  name: 'Ali',
  // role is optional because it has a default value
};

// The Row type reflects what the database returns
function display(user: UsersRow) {
  console.log(user.email, user.role);
}
```

**Import the OpenAPI spec into Postman, Insomnia, or Swagger UI** by pointing to `./generated/openapi.json`.

---

## Column Types

| Function | PostgreSQL Type |
|---|---|
| `uuid(name)` | UUID |
| `text(name)` | TEXT |
| `varchar(name, length?)` | VARCHAR(n) |
| `integer(name)` | INTEGER |
| `bigint(name)` | BIGINT |
| `boolean(name)` | BOOLEAN |
| `timestamp(name)` | TIMESTAMP WITHOUT TIME ZONE |
| `timestamptz(name)` | TIMESTAMP WITH TIME ZONE |
| `jsonb(name)` | JSONB |
| `float(name)` | DOUBLE PRECISION |
| `serial(name)` | SERIAL |

## Column Modifiers

```typescript
text('email')
  .notNull()
  .nullable()
  .unique()
  .default('value')
  .defaultNow()          // DEFAULT now()
  .defaultRandom()       // DEFAULT gen_random_uuid()
  .references('table', 'column', { onDelete: 'cascade' })
```

---

## Row Level Security

Policies are defined alongside your schema and compiled into PostgreSQL `CREATE POLICY` statements.

```typescript
const documents = table('documents', {
  id:      uuid('id').primaryKey().defaultRandom(),
  ownerId: uuid('owner_id').notNull(),
  content: text('content').notNull(),
})
  .policy('documents_owner_only', {
    for: 'all',
    to: 'authenticated',
    using: 'auth.uid() = owner_id',
    withCheck: 'auth.uid() = owner_id',
  });
```

The `PostgresSqlEmitter` automatically generates the `auth.uid()`, `auth.role()`, and `auth.email()` PostgreSQL functions that read values from per-request session variables. These are designed to work with any JWT-based authentication layer that sets those variables before executing queries.

Available policy operations for `for`: `select`, `insert`, `update`, `delete`, `all`.

---

## Emitter Options

### PostgresSqlEmitter

```typescript
sqlEmitter.emit(appSchema, {
  includeExtensions: true,   // CREATE EXTENSION IF NOT EXISTS "pgcrypto"
  includeAuthHelpers: true,  // generates auth.uid() / auth.role() / auth.email()
  dropIfExists: false,       // prepend DROP TABLE IF EXISTS ... CASCADE
  enableRlsByDefault: true,  // always ENABLE ROW LEVEL SECURITY on every table
});
```

### TsTypeEmitter

Returns the generated TypeScript code as a string instead of writing to disk.

```typescript
import { TsTypeEmitter } from '@clous/core';

const emitter = new TsTypeEmitter();
const code = emitter.emit(appSchema);
console.log(code);
```

### OpenApiEmitter

```typescript
openApiEmitter.emit(appSchema, {
  title: 'My API',
  description: 'Optional description',
  version: '1.0.0',
  serverUrl: 'https://api.example.com',
});
```

---

## Indexes

```typescript
table('posts', { ... })
  .index(['author_id'])                                          // simple index
  .index(['title', 'created_at'], { unique: true })             // composite unique index
  .index(['content'], { method: 'gin' })                        // GIN index (full-text search)
```

---

## License

MIT
# @clous/core

**Type-safe, compiler-driven schema builder for BaaS platforms.**  
Define your database schema once in TypeScript — Clous compiles it into:

- ✅ **PostgreSQL DDL** with `CREATE TABLE`, indexes, foreign keys and **Row Level Security (RLS) policies**
- ✅ **TypeScript types** (`Row`, `Insert`, `Update`, `Database`) as `.d.ts` files
- ✅ **OpenAPI 3.0 specification** for automatic REST API documentation

---

## Install

```bash
npm install @clous/core
# or
pnpm add @clous/core
```

**Requirements:** Node.js ≥ 20.0.0

---

## Quick Start

```typescript
import {
  schema,
  table,
  uuid,
  text,
  integer,
  boolean,
  timestamp,
  PostgresSqlEmitter,
  TsTypeEmitter,
  DtsEmitter,
  OpenApiEmitter,
} from '@clous/core';

// 1. Define your schema
const users = table('users', {
  id:        uuid('id').primaryKey().defaultRandom(),
  email:     text('email').unique().notNull(),
  name:      text('name').notNull(),
  role:      text('role').notNull().default('user'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})
  .policy('users_read_all', { for: 'select', using: 'true' })
  .policy('users_update_own', {
    for: 'update',
    to: 'authenticated',
    using: 'auth.uid() = id',
    withCheck: 'auth.uid() = id',
  });

const posts = table('posts', {
  id:       uuid('id').primaryKey().defaultRandom(),
  title:    text('title').notNull(),
  likes:    integer('likes').notNull().default(0),
  published: boolean('is_published').notNull().default(false),
  authorId: uuid('author_id')
    .notNull()
    .references('users', 'id', { onDelete: 'cascade' }),
})
  .index(['author_id'])
  .policy('posts_public_read', { for: 'select', using: 'is_published = true' });

// 2. Compile into an AST (validates structure + foreign key references)
const appSchema = schema({ tables: [users, posts] });

// 3. Emit PostgreSQL DDL
const sqlEmitter = new PostgresSqlEmitter();
const ddl = sqlEmitter.emit(appSchema);
console.log(ddl);

// 4. Emit TypeScript types as a string
const tsEmitter = new TsTypeEmitter();
const types = tsEmitter.emit(appSchema);

// 5. Write physical .d.ts file to disk
const dtsEmitter = new DtsEmitter();
await dtsEmitter.writeToFile('./generated/schema.d.ts', appSchema);

// 6. Generate OpenAPI 3.0 spec
const openApiEmitter = new OpenApiEmitter();
const spec = openApiEmitter.emit(appSchema, { title: 'My API', serverUrl: 'https://api.example.com' });
console.log(JSON.stringify(spec, null, 2));
```

---

## API Reference

### `schema(config)`

Compiles and validates a list of tables into a `SchemaNode` AST.

```typescript
const appSchema = schema({ version: '1.0.0', tables: [users, posts] });
```

- Validates all table/column names as safe SQL identifiers (via Zod).
- Checks that foreign key references point to existing tables and columns.
- Throws a descriptive error at compile time — not at runtime.

---

### Column Factory Functions

| Function | PostgreSQL Type |
|---|---|
| `uuid(name)` | `UUID` |
| `text(name)` | `TEXT` |
| `varchar(name, length?)` | `VARCHAR(n)` |
| `integer(name)` | `INTEGER` |
| `bigint(name)` | `BIGINT` |
| `boolean(name)` | `BOOLEAN` |
| `timestamp(name)` | `TIMESTAMP WITHOUT TIME ZONE` |
| `timestamptz(name)` | `TIMESTAMP WITH TIME ZONE` |
| `jsonb(name)` | `JSONB` |
| `float(name)` | `DOUBLE PRECISION` |
| `serial(name)` | `SERIAL` |

#### Column modifiers

```typescript
uuid('id')
  .primaryKey()        // PRIMARY KEY
  .notNull()           // NOT NULL
  .nullable()          // allow NULL
  .unique()            // UNIQUE constraint
  .default('value')    // DEFAULT 'value'
  .defaultNow()        // DEFAULT now()
  .defaultRandom()     // DEFAULT gen_random_uuid()
  .references('other_table', 'column', { onDelete: 'cascade' })
```

---

### `table(name, columns?)`

```typescript
table('posts', { ... })
  .policy('name', { for: 'select', using: 'true' })
  .index(['column1', 'column2'], { unique: true, method: 'btree' })
```

---

### Emitters

#### `PostgresSqlEmitter`

Generates PostgreSQL DDL including extensions, auth helper functions, indexes, and RLS policies.

```typescript
const emitter = new PostgresSqlEmitter();
const sql = emitter.emit(schema, {
  includeExtensions: true,    // adds CREATE EXTENSION IF NOT EXISTS "pgcrypto"
  includeAuthHelpers: true,   // generates auth.uid() / auth.role() helper functions
  dropIfExists: false,        // prepend DROP TABLE IF EXISTS ... CASCADE
  enableRlsByDefault: true,   // always ENABLE ROW LEVEL SECURITY
});
```

#### `TsTypeEmitter`

Generates TypeScript interfaces as a string.

```typescript
const emitter = new TsTypeEmitter();
const code = emitter.emit(schema, { includeHeader: true });
// Returns: UsersRow, UsersInsert, UsersUpdate, Database, ...
```

#### `DtsEmitter`

Writes TypeScript definitions to a physical `.d.ts` file.

```typescript
const emitter = new DtsEmitter();
await emitter.writeToFile('./generated/schema.d.ts', schema);
```

#### `OpenApiEmitter`

Generates an OpenAPI 3.0 specification object.

```typescript
const emitter = new OpenApiEmitter();
const spec = emitter.emit(schema, {
  title: 'My API',
  description: 'Auto-generated REST API specification',
  serverUrl: 'https://api.example.com',
});
```

---

## Row Level Security (RLS)

RLS policies are defined declaratively alongside the schema and compiled directly into PostgreSQL `CREATE POLICY` statements.

```typescript
table('documents', { ... })
  .policy('docs_user_access', {
    for: 'all',
    to: 'authenticated',            // PostgreSQL role
    using: 'auth.uid() = owner_id', // filter existing rows
    withCheck: 'auth.uid() = owner_id', // validate new/updated rows
  });
```

The `auth.uid()`, `auth.role()`, and `auth.email()` functions are generated automatically by `PostgresSqlEmitter` via `CREATE OR REPLACE FUNCTION auth.uid()` — reading values from PostgreSQL session variables set per-request.

---

## License

MIT © [Efekan Bahçeci](https://github.com/efekanbahceci)

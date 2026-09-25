# Clous 

##  What is Clous?

**Clous** completely automates backend infrastructure. By defining a single declarative schema in TypeScript, Clous compiles and generates:
1. **Isolated PostgreSQL Databases**: Provisioned per project with native Row Level Security (RLS).
2. **End-to-End TypeScript SDK**: Auto-generated `.d.ts` types and client queries without manual mapping.
3. **Dynamic JWT-Secured REST / GraphQL APIs**: Ready-to-use CRUD endpoints adhering to RLS policies.
4. **Declarative Security**: Define complex authorization rules in pure TypeScript without touching raw SQL.

---

##  Monorepo Architecture

```
clous/
├── packages/
│   └── core/            # The Core Engine (Compiler, AST, Builder, Emitters)
│       ├── src/
│       │   ├── ast/     # AST definitions & Zod validation schemas
│       │   ├── builder/ # Fluent schema builder API
│       │   └── emitters/# PostgresSqlEmitter, TsTypeEmitter
│       └── tests/       # Vitest unit test suite
├── examples/
│   └── basic/           # Working end-to-end compilation demo
├── ARCHITECTURE.md      # Detailed system design & roadmaps
├── pnpm-workspace.yaml
└── package.json
```

---

##  Quickstart & Demo

### 1. Install Dependencies
```bash
pnpm install
```

### 2. Run Tests
```bash
pnpm test
```

### 3. Run the Core Compiler Demo
```bash
pnpm demo
```

---

## Example: Defining a Schema

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
} from '@clous/core';

// 1. Define Users with Row Level Security (RLS)
const users = table('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: text('email').unique().notNull(),
  fullName: text('full_name').notNull(),
  role: text('role').notNull().default('customer'),
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

// 2. Define Products
const products = table('products', {
  id: uuid('id').primaryKey().defaultRandom(),
  title: text('title').notNull(),
  price: integer('price').notNull(),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})
  .index(['title'])
  .policy('products_public_read', {
    for: 'select',
    using: 'is_active = true',
  });

// 3. Define Orders with Foreign Key
const orders = table('orders', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .notNull()
    .references('users', 'id', { onDelete: 'cascade' }),
  total: integer('total').notNull(),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})
  .index(['user_id'])
  .policy('orders_user_own', {
    for: 'all',
    to: 'authenticated',
    using: 'auth.uid() = user_id',
    withCheck: 'auth.uid() = user_id',
  });

// 4. Compile into AST
export const appSchema = schema({
  tables: [users, products, orders],
});

// 5. Emit PostgreSQL DDL & TypeScript Types
const sqlEmitter = new PostgresSqlEmitter();
const tsEmitter = new TsTypeEmitter();

const ddl = sqlEmitter.emit(appSchema);
const types = tsEmitter.emit(appSchema);
```

---

##  Roadmap Status

- [x] **Phase 1: Core Engine Prototype (Local-First)** *(Current)*
  - Abstract Syntax Tree (AST) & Intermediate Representation (IR)
  - Zod structural validation & foreign-key semantic checks
  - Fluent Builder API (`table`, `column`, `policy`, `references`)
  - `PostgresSqlEmitter` (DDL, Constraints, Indexes, RLS Policies)
  - `TsTypeEmitter` (Row, Insert, Update, Database interfaces)
  - Vitest test suite with 100% pass rate
- [ ] **Phase 2: Type Safety & Dynamic Runtime API** (ts-morph, Fastify CRUD)
- [ ] **Phase 3: Developer CLI & Local Docker Compose**
- [ ] **Phase 4: Control Plane & SaaS Dashboard**
- [ ] **Phase 5: Cloud Orchestration (MicroVMs / Docker & Caddy Gateway)**

For comprehensive system diagrams and deep-dives, see [ARCHITECTURE.md](file:///Users/efekan/Desktop/Projeler/clous/ARCHITECTURE.md).
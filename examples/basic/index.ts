import {
  schema,
  table,
  uuid,
  text,
  integer,
  boolean,
  timestamp,
  jsonb,
  PostgresSqlEmitter,
  TsTypeEmitter,
} from '../../packages/core/dist/index.js';

// 1. Define Users Table with declarative Row Level Security (RLS)
const users = table('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: text('email').unique().notNull(),
  fullName: text('full_name').notNull(),
  role: text('role').notNull().default('customer'),
  avatarUrl: text('avatar_url'),
  metadata: jsonb('metadata'),
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

// 2. Define Products Table with Index
const products = table('products', {
  id: uuid('id').primaryKey().defaultRandom(),
  title: text('title').notNull(),
  description: text('description'),
  price: integer('price').notNull(),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})
  .index(['title'])
  .policy('products_public_read', {
    for: 'select',
    using: 'is_active = true',
  });

// 3. Define Orders Table with Foreign Key Relations
const orders = table('orders', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .notNull()
    .references('users', 'id', { onDelete: 'cascade' }),
  status: text('status').notNull().default('pending'),
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

// 4. Compile Schema (Builds and Validates AST / IR)
export const appSchema = schema({
  version: '1.0.0',
  tables: [users, products, orders],
});

// 5. Emit outputs
const sqlEmitter = new PostgresSqlEmitter();
const tsEmitter = new TsTypeEmitter();

console.log('==============================================');
console.log('CLOUS COMPILER DEMO: GENERATED POSTGRESQL DDL');
console.log('==============================================');
console.log(sqlEmitter.emit(appSchema));

console.log('==============================================');
console.log('CLOUS COMPILER DEMO: GENERATED TYPESCRIPT TYPES');
console.log('==============================================');
console.log(tsEmitter.emit(appSchema));

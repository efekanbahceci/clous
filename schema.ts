import {
  schema,
  table,
  uuid,
  text,
  integer,
  boolean,
  timestamp,
} from '@clous/core';

// 1. Define Users table with Row Level Security (RLS)
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

// 2. Define Posts table with foreign key reference
export const posts = table('posts', {
  id: uuid('id').primaryKey().defaultRandom(),
  title: text('title').notNull(),
  content: text('content').notNull(),
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

// 3. Compile and export application schema
export const appSchema = schema({
  version: '1.0.0',
  tables: [users, posts],
});

export default appSchema;

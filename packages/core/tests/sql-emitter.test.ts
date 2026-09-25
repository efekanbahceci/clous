import { describe, it, expect } from 'vitest';
import {
  schema,
  table,
  uuid,
  text,
  boolean,
  PostgresSqlEmitter,
} from '../src/index.js';

describe('Clous Core - PostgresSqlEmitter', () => {
  it('should emit valid PostgreSQL DDL with RLS', () => {
    const users = table('users', {
      id: uuid('id').primaryKey().defaultRandom(),
      email: text('email').unique().notNull(),
      is_active: boolean('is_active').default(true),
    }).policy('users_read_all', {
      for: 'select',
      using: 'true',
    });

    const ast = schema({ tables: [users] });
    const emitter = new PostgresSqlEmitter();
    const sql = emitter.emit(ast);

    expect(sql).toContain('CREATE EXTENSION IF NOT EXISTS "pgcrypto";');
    expect(sql).toContain('CREATE TABLE IF NOT EXISTS "users" (');
    expect(sql).toContain('"id" UUID PRIMARY KEY DEFAULT gen_random_uuid()');
    expect(sql).toContain('"email" TEXT NOT NULL UNIQUE');
    expect(sql).toContain('"is_active" BOOLEAN DEFAULT TRUE');
    expect(sql).toContain('ALTER TABLE "users" ENABLE ROW LEVEL SECURITY;');
    expect(sql).toContain(
      'CREATE POLICY "users_read_all" ON "users"\n  FOR SELECT\n  USING (true);'
    );
  });

  it('should emit foreign key references correctly', () => {
    const authors = table('authors', {
      id: uuid('id').primaryKey().defaultRandom(),
      name: text('name').notNull(),
    });

    const articles = table('articles', {
      id: uuid('id').primaryKey().defaultRandom(),
      title: text('title').notNull(),
      authorId: uuid('author_id')
        .notNull()
        .references('authors', 'id', { onDelete: 'cascade' }),
    });

    const ast = schema({ tables: [authors, articles] });
    const emitter = new PostgresSqlEmitter();
    const sql = emitter.emit(ast);

    expect(sql).toContain(
      'REFERENCES "authors" ("id") ON DELETE CASCADE'
    );
  });
});

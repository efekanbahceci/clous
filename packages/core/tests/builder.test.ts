import { describe, it, expect } from 'vitest';
import {
  schema,
  table,
  uuid,
  text,
  integer,
  boolean,
  timestamp,
} from '../src/index.js';

describe('Clous Core - Schema & Builder', () => {
  it('should correctly build a simple table AST', () => {
    const users = table('users', {
      id: uuid('id').primaryKey().defaultRandom(),
      email: text('email').unique().notNull(),
      name: text('name'),
      age: integer('age'),
      isActive: boolean('is_active').default(true),
      createdAt: timestamp('created_at').defaultNow(),
    });

    const ast = schema({
      tables: [users],
    });

    expect(ast.tables).toHaveLength(1);
    const userTable = ast.tables[0];
    expect(userTable.name).toBe('users');
    expect(userTable.columns).toHaveLength(6);

    const idCol = userTable.columns.find((c) => c.name === 'id');
    expect(idCol?.isPrimaryKey).toBe(true);
    expect(idCol?.isNullable).toBe(false);
    expect(idCol?.defaultValue).toEqual({
      kind: 'raw',
      expression: 'gen_random_uuid()',
    });

    const emailCol = userTable.columns.find((c) => c.name === 'email');
    expect(emailCol?.isUnique).toBe(true);
    expect(emailCol?.isNullable).toBe(false);
  });

  it('should support relationships and foreign keys', () => {
    const users = table('users', {
      id: uuid('id').primaryKey().defaultRandom(),
      email: text('email').notNull(),
    });

    const posts = table('posts', {
      id: uuid('id').primaryKey().defaultRandom(),
      title: text('title').notNull(),
      userId: uuid('user_id').references('users', 'id', {
        onDelete: 'cascade',
      }),
    });

    const ast = schema({
      tables: [users, posts],
    });

    expect(ast.tables).toHaveLength(2);
    const postTable = ast.tables.find((t) => t.name === 'posts');
    const userRef = postTable?.columns.find((c) => c.name === 'user_id');
    expect(userRef?.references).toEqual({
      table: 'users',
      column: 'id',
      onDelete: 'cascade',
      onUpdate: undefined,
    });
  });

  it('should fail validation if foreign key references nonexistent table or column', () => {
    const posts = table('posts', {
      id: uuid('id').primaryKey().defaultRandom(),
      userId: uuid('user_id').references('non_existent', 'id'),
    });

    expect(() => {
      schema({ tables: [posts] });
    }).toThrow(/referenced table "non_existent" does not exist/);
  });

  it('should fail validation if duplicate table names exist', () => {
    const t1 = table('items', { id: uuid('id').primaryKey() });
    const t2 = table('items', { id: uuid('id').primaryKey() });

    expect(() => {
      schema({ tables: [t1, t2] });
    }).toThrow(/Duplicate table definition/);
  });

  it('should allow declarative RLS policies', () => {
    const posts = table('posts', {
      id: uuid('id').primaryKey().defaultRandom(),
      title: text('title').notNull(),
      authorId: uuid('author_id').notNull(),
    })
      .policy('posts_select_all', {
        for: 'select',
        using: 'true',
      })
      .policy('posts_modify_author', {
        for: 'all',
        to: 'authenticated',
        using: 'auth.uid() = author_id',
        withCheck: 'auth.uid() = author_id',
      });

    const ast = schema({ tables: [posts] });
    expect(ast.tables[0].policies).toHaveLength(2);
    expect(ast.tables[0].policies[0].name).toBe('posts_select_all');
    expect(ast.tables[0].policies[1].to).toBe('authenticated');
  });
});

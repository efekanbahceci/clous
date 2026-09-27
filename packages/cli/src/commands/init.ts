import fs from 'node:fs';
import path from 'node:path';
import { logger } from '../utils/logger.js';
import { ansi } from '../utils/ansi.js';

export interface InitOptions {
  cwd?: string;
  force?: boolean;
}

const STARTER_SCHEMA = `import {
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
`;

export async function initCommand(options: InitOptions = {}): Promise<void> {
  const cwd = options.cwd || process.cwd();
  const schemaPath = path.join(cwd, 'schema.ts');

  if (fs.existsSync(schemaPath) && !options.force) {
    logger.warn(`File "schema.ts" already exists in ${cwd}. Use --force to overwrite.`);
    return;
  }

  // Write schema.ts
  fs.writeFileSync(schemaPath, STARTER_SCHEMA, 'utf8');

  // Create .clous directory
  const clousDir = path.join(cwd, '.clous');
  if (!fs.existsSync(clousDir)) {
    fs.mkdirSync(clousDir, { recursive: true });
  }

  // Update .gitignore if present
  const gitignorePath = path.join(cwd, '.gitignore');
  if (fs.existsSync(gitignorePath)) {
    try {
      const content = fs.readFileSync(gitignorePath, 'utf8');
      if (!content.includes('.clous/credentials.json')) {
        fs.appendFileSync(
          gitignorePath,
          '\n# Clous CLI\n.clous/credentials.json\n.clous/.cache\n'
        );
      }
    } catch {
      // Ignore gitignore write error
    }
  }

  logger.success('Initialized new Clous project successfully.');
  logger.plain('');
  logger.plain('Created files:');
  logger.plain(`  ${ansi.cyan('+')} schema.ts`);
  logger.plain(`  ${ansi.cyan('+')} .clous/`);
  logger.plain('');
  logger.plain('Next steps:');
  logger.plain(`  1. Run ${ansi.bold('npx clous generate')} to compile SQL and TypeScript types.`);
  logger.plain(`  2. Run ${ansi.bold('npx clous dev')} to watch schema changes automatically.`);
  logger.plain(`  3. Run ${ansi.bold('npx clous login')} to connect to the Clous Web Panel.`);
}

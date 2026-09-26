import {
  schema,
  table,
  uuid,
  text,
  integer,
  boolean,
  timestamp,
  PostgresSqlEmitter,
  DtsEmitter,
} from '../../packages/core/dist/index.js';
import { createClousServer } from '../../packages/server/dist/index.js';

async function main() {
  console.log('⚡ 1. Building Schema (AST / IR)...');

  // Define Schema
  const users = table('users', {
    id: uuid('id').primaryKey().defaultRandom(),
    email: text('email').unique().notNull(),
    fullName: text('full_name').notNull(),
    role: text('role').notNull().default('user'),
    createdAt: timestamp('created_at').notNull().defaultNow(),
  }).policy('users_read_all', {
    for: 'select',
    using: 'true',
  });

  const posts = table('posts', {
    id: uuid('id').primaryKey().defaultRandom(),
    title: text('title').notNull(),
    content: text('content'),
    authorId: uuid('author_id')
      .notNull()
      .references('users', 'id', { onDelete: 'cascade' }),
    likes: integer('likes').notNull().default(0),
    isPublished: boolean('is_published').notNull().default(false),
  });

  const appSchema = schema({
    version: '1.0.0',
    tables: [users, posts],
  });

  console.log('⚡ 2. Emitting Physical .d.ts File...');
  const dtsEmitter = new DtsEmitter();
  const dtsPath = await dtsEmitter.writeToFile(
    './dist/types/clous-schema.d.ts',
    appSchema
  );
  console.log(`   --> Type definitions written to: ${dtsPath}`);

  console.log('⚡ 3. Starting Headless Clous Runtime Engine...');
  const server = await createClousServer({
    schema: appSchema,
    database: { provider: 'memory' }, // In-memory for instant demonstration
    auth: {
      jwtSecret: 'clous-demo-secret-key-32-characters-minimum',
    },
    security: {
      rateLimit: false, // disabled for fast demo calls
    },
  });

  await server.ready();
  console.log('   --> Clous API server is ready in-memory!');

  console.log('\n⚡ 4. Testing Dynamic CRUD API Endpoints:');

  // 1. Create a user
  const userRes = await server.inject({
    method: 'POST',
    url: '/api/users',
    payload: {
      email: 'alex@example.com',
      full_name: 'Alex Johnson',
      role: 'admin',
    },
  });
  console.log('   [POST /api/users] Status:', userRes.statusCode);
  const createdUser = JSON.parse(userRes.payload).data;
  console.log('   Created User ID:', createdUser.id);

  // 2. Create a post referencing user
  const postRes = await server.inject({
    method: 'POST',
    url: '/api/posts',
    payload: {
      title: 'Hello Clous!',
      content: 'Building a next-gen BaaS platform with TypeScript.',
      author_id: createdUser.id,
      is_published: true,
    },
  });
  console.log('   [POST /api/posts] Status:', postRes.statusCode);
  const createdPost = JSON.parse(postRes.payload).data;

  // 3. Query posts with filters and pagination
  const listRes = await server.inject({
    method: 'GET',
    url: '/api/posts?is_published=true&limit=10',
  });
  console.log('   [GET /api/posts?is_published=true] Status:', listRes.statusCode);
  const postList = JSON.parse(listRes.payload);
  console.log('   Found posts count:', postList.data.length);
  console.log('   Pagination total:', postList.pagination.total);

  // 4. Update post
  const patchRes = await server.inject({
    method: 'PATCH',
    url: `/api/posts/${createdPost.id}`,
    payload: {
      likes: 42,
    },
  });
  console.log('   [PATCH /api/posts/:id] Status:', patchRes.statusCode);
  console.log('   Updated likes:', JSON.parse(patchRes.payload).data.likes);

  // 5. Check Health endpoint
  const healthRes = await server.inject({
    method: 'GET',
    url: '/api/_clous/health',
  });
  console.log('   [GET /api/_clous/health] Status:', healthRes.statusCode);
  console.log('   Health payload:', JSON.parse(healthRes.payload));

  await server.close();
  console.log('\n✅ Demo completed successfully! Server shut down cleanly.');
}

main().catch(console.error);

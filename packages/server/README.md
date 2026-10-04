# @clous/server

**Clous Runtime Engine** - The dynamic, type-safe CRUD server with Row Level Security (RLS) and real-time Web Panel Integration.

This is the core execution engine for Clous projects. It dynamically turns your defined schemas into fully working, high-performance REST APIs powered by Fastify. It manages database connections, handles authentication/authorization, and synchronizes real-time traffic and latency metrics directly to your Clous Dashboard (`clous.dev`).

## Installation

```bash
npm install @clous/server @clous/core
```

## Quick Start

```typescript
import { createServer } from '@clous/server';

const server = await createServer({
  port: 4000,
  database: 'postgres://user:pass@localhost:5432/db',
  // ... configuration
});

await server.start();
console.log('Clous Runtime Engine is listening on port 4000');
```

## Features
- **Dynamic Routing:** Instantly maps schemas to CRUD endpoints.
- **Row Level Security:** Bulletproof data access rules directly executed in the runtime.
- **Cloud Sync:** Securely streams traffic, errors, and latency metrics to `https://clous.dev`.
- **High Performance:** Powered by Fastify and optimized Postgres querying.

## License
MIT

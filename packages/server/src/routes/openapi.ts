import type { FastifyPluginAsync } from 'fastify';
import { OpenApiEmitter, type SchemaNode } from '@clous/core';

export const openapiRoutes: FastifyPluginAsync<{
  getSchema: () => SchemaNode;
}> = async (fastify, opts) => {
  const { getSchema } = opts;
  const openApiEmitter = new OpenApiEmitter();

  // 1. Return raw OpenAPI 3.0 specification in JSON
  fastify.get('/api/_clous/openapi.json', async (_req, reply) => {
    const spec = openApiEmitter.emit(getSchema(), {
      title: 'Clous Project API',
      description:
        'Live REST API dynamically compiled and served by Clous BaaS Runtime',
    });

    return reply.send(spec);
  });

  // 2. Interactive API Documentation Playground (Scalar / Modern UI)
  fastify.get('/api/_clous/docs', async (_req, reply) => {
    const html = `<!doctype html>
<html>
  <head>
    <title>Clous API Reference & Playground</title>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <link rel="icon" type="image/svg+xml" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>⚡</text></svg>">
    <style>
      body {
        margin: 0;
        padding: 0;
        background: #0f172a;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
      }
    </style>
  </head>
  <body>
    <script
      id="api-reference"
      data-url="/api/_clous/openapi.json"
      data-configuration='{"theme":"purple","darkMode":true,"layout":"modern"}'
      src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"
    ></script>
  </body>
</html>`;

    return reply.type('text/html').send(html);
  });
};

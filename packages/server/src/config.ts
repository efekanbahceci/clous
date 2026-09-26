import type { SchemaNode } from '@clous/core';
import type { FastifyCorsOptions } from '@fastify/cors';
import type { RateLimitOptions } from '@fastify/rate-limit';
import type { Pool } from 'pg';

export interface DatabaseConfig {
  provider?: 'postgres' | 'memory';
  connectionString?: string;
  pool?: Pool;
  maxConnections?: number;
}

export interface AuthConfig {
  jwtSecret?: string;
  required?: boolean;
}

export interface SecurityConfig {
  cors?: boolean | FastifyCorsOptions;
  rateLimit?: boolean | RateLimitOptions;
  helmet?: boolean;
}

export interface AdminConfig {
  secret?: string;
  allowSchemaUpdates?: boolean;
}

export interface ServerConfig {
  port?: number;
  host?: string;
  logger?: boolean;
}

export interface ClousServerOptions {
  schema: SchemaNode;
  database?: DatabaseConfig;
  auth?: AuthConfig;
  security?: SecurityConfig;
  admin?: AdminConfig;
  server?: ServerConfig;
}

import type { FastifyPluginAsync } from 'fastify';
import fastifyCors from '@fastify/cors';
import fastifyHelmet from '@fastify/helmet';
import fastifyRateLimit from '@fastify/rate-limit';
import type { SecurityConfig } from '../config.js';

export const securityPlugin: FastifyPluginAsync<{ config?: SecurityConfig }> =
  async (fastify, opts) => {
    const { config } = opts;

    // 1. CORS
    if (config?.cors !== false) {
      const corsOptions =
        typeof config?.cors === 'object'
          ? config.cors
          : {
              origin: true,
              credentials: true,
              methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
              allowedHeaders: [
                'Content-Type',
                'Authorization',
                'X-Clous-Admin-Secret',
                'X-Requested-With',
              ],
            };
      await fastify.register(fastifyCors, corsOptions);
    }

    // 2. Helmet (Security Headers)
    if (config?.helmet !== false) {
      await fastify.register(fastifyHelmet, {
        contentSecurityPolicy: false, // Allows embedding in Web Panel iframes/docs
        crossOriginEmbedderPolicy: false,
      });
    }

    // 3. Rate Limit
    if (config?.rateLimit !== false) {
      const rateLimitOptions =
        typeof config?.rateLimit === 'object'
          ? config.rateLimit
          : {
              max: 500, // 500 requests per minute
              timeWindow: '1 minute',
            };
      await fastify.register(fastifyRateLimit, rateLimitOptions);
    }
  };

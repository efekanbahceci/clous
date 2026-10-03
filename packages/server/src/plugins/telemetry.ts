import fp from 'fastify-plugin';
import { EventEmitter } from 'events';
import crypto from 'crypto';
import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';

export interface TelemetryMetric {
  id: string;
  method: string;
  path: string;
  status: number;
  duration: number;
  timestamp: string;
}

// Global emitter for telemetry events
export const telemetryEmitter = new EventEmitter();
// Allow many concurrent Dashboard connections
telemetryEmitter.setMaxListeners(100);

export const telemetryPlugin = fp(async (fastify: FastifyInstance) => {
  fastify.addHook('onRequest', (request: FastifyRequest, reply: FastifyReply, done) => {
    // Record start time using high-resolution real time
    (request as any).telemetryStartTime = process.hrtime.bigint();
    done();
  });

  fastify.addHook('onResponse', (request: FastifyRequest, reply: FastifyReply, done) => {
    const startTime = (request as any).telemetryStartTime;
    if (startTime) {
      const endTime = process.hrtime.bigint();
      // Calculate duration in milliseconds
      const durationMs = Number(endTime - startTime) / 1_000_000;

      // Do not log the telemetry stream endpoint itself to prevent feedback loops
      const path = request.routeOptions?.url || request.url;
      if (!path.includes('/telemetry/stream')) {
        const metric: TelemetryMetric = {
          id: crypto.randomUUID(),
          method: request.method,
          path,
          status: reply.statusCode,
          duration: durationMs,
          timestamp: new Date().toISOString(),
        };

        telemetryEmitter.emit('metric', metric);
        console.log('[Telemetry] Metrik Gönderildi:', metric.method, metric.path);
      }
    }
    done();
  });
});

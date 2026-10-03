import fp from 'fastify-plugin';
import fs from 'fs';
import path from 'path';
import { telemetryEmitter } from './telemetry.js';
import crypto from 'crypto';

export const envScannerPlugin = fp(async (fastify) => {
  const envPath = path.resolve(process.cwd(), '.env');
  let previousEnvs: Record<string, string> | null = null;
  
  const scanAndSync = () => {
    try {
      if (fs.existsSync(envPath)) {
        const content = fs.readFileSync(envPath, 'utf8');
        const envs = [];
        const currentEnvMap: Record<string, string> = {};
        
        const lines = content.split('\n');
        for (const line of lines) {
          const trimmed = line.trim();
          if (trimmed && !trimmed.startsWith('#') && trimmed.includes('=')) {
            const [key, ...rest] = trimmed.split('=');
            const parsedKey = key.trim();
            const parsedVal = rest.join('=').trim();
            envs.push({ key: parsedKey, value: parsedVal });
            currentEnvMap[parsedKey] = parsedVal;
          }
        }
        
        // Compute audit logs if we have a previous state
        if (previousEnvs !== null) {
           const auditLogs = [];
           const timestamp = new Date().toISOString();
           const ip = '127.0.0.1 (Local CLI)';
           
           for (const [k, v] of Object.entries(currentEnvMap)) {
             if (!(k in previousEnvs)) {
               auditLogs.push({ id: crypto.randomUUID(), key: k, action: 'Eklendi', timestamp, ip });
             } else if (previousEnvs[k] !== v) {
               auditLogs.push({ id: crypto.randomUUID(), key: k, action: 'Güncellendi', timestamp, ip });
             }
           }
           for (const k of Object.keys(previousEnvs)) {
             if (!(k in currentEnvMap)) {
               auditLogs.push({ id: crypto.randomUUID(), key: k, action: 'Silindi', timestamp, ip });
             }
           }
           
           if (auditLogs.length > 0) {
             telemetryEmitter.emit('env_audit', auditLogs);
           }
        }
        
        previousEnvs = currentEnvMap;
        telemetryEmitter.emit('env_sync', envs);
        console.log(`[EnvScanner] .env dosyası tarandı, Dashboard'a aktarılıyor (${envs.length} key)`);
      } else {
        if (previousEnvs !== null && Object.keys(previousEnvs).length > 0) {
            const auditLogs = [];
            const timestamp = new Date().toISOString();
            const ip = '127.0.0.1 (Local CLI)';
            for (const k of Object.keys(previousEnvs)) {
               auditLogs.push({ id: crypto.randomUUID(), key: k, action: 'Silindi', timestamp, ip });
            }
            telemetryEmitter.emit('env_audit', auditLogs);
        }
        previousEnvs = {};
        telemetryEmitter.emit('env_sync', []);
      }
    } catch (e) {
      console.error("[EnvScanner] .env okuma hatası:", e);
    }
  };

  fastify.addHook('onReady', async () => {
    scanAndSync();
  });

  const dirPath = process.cwd();
  try {
    fs.watch(dirPath, (eventType, filename) => {
      if (filename === '.env') {
        scanAndSync();
      }
    });
  } catch (err) {
    if (fs.existsSync(envPath)) {
      fs.watchFile(envPath, { interval: 1000 }, (curr, prev) => {
        if (curr.mtime !== prev.mtime) {
          scanAndSync();
        }
      });
    }
  }

  telemetryEmitter.on('client_connected', () => {
    // When a new dashboard client connects, just send the current env state (no audit triggers)
    if (previousEnvs !== null) {
      const envs = Object.entries(previousEnvs).map(([k,v]) => ({ key: k, value: v }));
      telemetryEmitter.emit('env_sync', envs);
    } else {
      scanAndSync();
    }
  });
});

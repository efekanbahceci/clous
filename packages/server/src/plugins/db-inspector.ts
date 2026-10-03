import fp from 'fastify-plugin';
import fs from 'node:fs';
import path from 'node:path';
import { telemetryEmitter } from './telemetry.js';
import { MongoClient } from 'mongodb';

export const dbInspectorPlugin = fp(async (fastify) => {
  let isInspecting = false;

  // Helper to read project config
  const getProjectConfig = () => {
    let current = process.cwd();
    while (true) {
      const p = path.join(current, '.clous');
      if (fs.existsSync(p) && fs.statSync(p).isDirectory()) {
        try {
          return JSON.parse(fs.readFileSync(path.join(p, 'project.json'), 'utf8'));
        } catch { return null; }
      }
      const parent = path.dirname(current);
      if (parent === current) break;
      current = parent;
    }
    return null;
  };

  // Helper to read .env
  const getEnvConfig = () => {
    try {
      const envPath = path.resolve(process.cwd(), '.env');
      if (fs.existsSync(envPath)) {
        const content = fs.readFileSync(envPath, 'utf8');
        const envs: Record<string, string> = {};
        for (const line of content.split('\n')) {
          const trimmed = line.trim();
          if (trimmed && !trimmed.startsWith('#') && trimmed.includes('=')) {
            const [k, ...v] = trimmed.split('=');
            envs[k.trim()] = v.join('=').trim().replace(/^['"]|['"]$/g, '');
          }
        }
        return envs;
      }
    } catch { }
    return {};
  };

  const inspectMongoDB = async (uri: string) => {
    let client;
    try {
      client = new MongoClient(uri, { serverSelectionTimeoutMS: 5000 });
      await client.connect();
      const db = client.db();
      const collections = await db.listCollections().toArray();
      
      const schemaData = [];
      for (const col of collections) {
        if (col.type !== 'collection' && col.type !== 'view') continue;
        const name = col.name;
        
        // Sample 5 documents to infer schema fields
        const sampleDocs = await db.collection(name).find().limit(5).toArray();
        const fields = new Map<string, string>();
        
        for (const doc of sampleDocs) {
          for (const [key, value] of Object.entries(doc)) {
            if (!fields.has(key)) {
              fields.set(key, typeof value);
            }
          }
        }
        
        schemaData.push({
          collection: name,
          fields: Array.from(fields.entries()).map(([k, t]) => ({ name: k, type: t }))
        });
      }
      
      telemetryEmitter.emit('schema_sync', {
        driver: 'mongodb',
        collections: schemaData,
        timestamp: new Date().toISOString()
      });
      console.log(`[DBInspector] MongoDB schema extracted (${schemaData.length} collections)`);
    } catch (e: any) {
      console.error('[DBInspector] Error inspecting MongoDB:', e.message);
    } finally {
      if (client) await client.close();
    }
  };

  const inspectPostgreSQL = async (uri: string) => {
    // Requires pg driver, falling back to basic mock if not available to prevent crashes
    try {
      const { default: pg } = await import('pg');
      const client = new pg.Client({ connectionString: uri });
      await client.connect();
      
      const query = `
        SELECT table_name, column_name, data_type 
        FROM information_schema.columns 
        WHERE table_schema = 'public'
      `;
      const res = await client.query(query);
      
      const schemaData = new Map<string, any[]>();
      for (const row of res.rows) {
        if (!schemaData.has(row.table_name)) {
          schemaData.set(row.table_name, []);
        }
        schemaData.get(row.table_name)!.push({
          name: row.column_name,
          type: row.data_type
        });
      }
      
      const formattedData = Array.from(schemaData.entries()).map(([table, fields]) => ({
        collection: table,
        fields
      }));

      telemetryEmitter.emit('schema_sync', {
        driver: 'postgresql',
        collections: formattedData,
        timestamp: new Date().toISOString()
      });
      console.log(`[DBInspector] PostgreSQL schema extracted (${formattedData.length} tables)`);
      
      await client.end();
    } catch (e: any) {
      console.error('[DBInspector] Error inspecting PostgreSQL:', e.message);
    }
  };

  const runIntrospection = async () => {
    if (isInspecting) return;
    isInspecting = true;
    
    try {
      const config = getProjectConfig();
      if (!config?.permissions?.dbIntrospection) return;
      
      const envs = getEnvConfig();
      const driver = config.database?.driver;
      let envKey = config.database?.envKey || 'DATABASE_URL';
      
      // Smart Fallback if the saved envKey isn't in .env
      if (!envs[envKey]) {
        if (envs['MONGODB_URI']) envKey = 'MONGODB_URI';
        else if (envs['POSTGRES_URL']) envKey = 'POSTGRES_URL';
        else if (envs['DATABASE_URL']) envKey = 'DATABASE_URL';
      }
      
      const uri = envs[envKey];
      
      if (!uri) {
        console.warn(`[DBInspector] No database URI found in .env (checked ${envKey})`);
        return;
      }
      
      if (driver === 'mongodb' || uri.includes('mongodb')) {
        await inspectMongoDB(uri);
      } else if (driver === 'postgresql' || uri.includes('postgres')) {
        await inspectPostgreSQL(uri);
      }
    } finally {
      isInspecting = false;
    }
  };

  // Run on startup
  fastify.addHook('onReady', async () => {
    runIntrospection();
  });

  // Re-run when a new dashboard connects
  telemetryEmitter.on('client_connected', () => {
    runIntrospection();
  });

  // Periodic refresh so schema changes reach the cloud without an open dashboard.
  // Cloud sync de-duplicates unchanged snapshots, so this is cheap.
  const refreshTimer = setInterval(() => runIntrospection(), 5 * 60_000);
  refreshTimer.unref();
  fastify.addHook('onClose', async () => clearInterval(refreshTimer));
});

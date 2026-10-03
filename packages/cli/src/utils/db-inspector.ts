import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { ProjectConfigManager } from '../config/project.js';

export async function introspectDatabase(cwd: string) {
  const config = ProjectConfigManager.load(cwd);
  if (!config) return null;

  const envs = getEnvConfig(cwd);
  const driver = config.database?.driver;
  let envKey = config.database?.envKey || 'DATABASE_URL';

  if (!envs[envKey]) {
    if (envs['MONGODB_URI']) envKey = 'MONGODB_URI';
    else if (envs['POSTGRES_URL']) envKey = 'POSTGRES_URL';
    else if (envs['DATABASE_URL']) envKey = 'DATABASE_URL';
  }

  const uri = envs[envKey];
  if (!uri) return null;

  if (driver === 'mongodb' || uri.includes('mongodb')) {
    return await inspectMongoDB(uri, cwd);
  } else if (driver === 'postgresql' || uri.includes('postgres')) {
    return await inspectPostgreSQL(uri, cwd);
  }
  return null;
}

function getEnvConfig(cwd: string) {
  try {
    const envPath = path.resolve(cwd, '.env');
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
}

async function inspectMongoDB(uri: string, cwd: string) {
  try {
    const require = createRequire(path.join(cwd, 'package.json'));
    const mongoPath = require.resolve('mongodb');
    const { MongoClient } = await import(mongoPath);
    
    const client = new MongoClient(uri, { serverSelectionTimeoutMS: 5000 });
    await client.connect();
    const db = client.db();
    const collections = await db.listCollections().toArray();
    
    const schemaData = [];
    for (const col of collections) {
      if (col.type !== 'collection' && col.type !== 'view') continue;
      const name = col.name;
      
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
        fields: Array.from(fields.entries()).map(([k, t]) => ({ name: k, type: t as string }))
      });
    }
    
    await client.close();
    return { driver: 'mongodb', collections: schemaData, timestamp: new Date().toISOString() };
  } catch (e: any) {
    // silently fail or warn if driver is not installed
    return null;
  }
}

async function inspectPostgreSQL(uri: string, cwd: string) {
  try {
    const require = createRequire(path.join(cwd, 'package.json'));
    const pgPath = require.resolve('pg');
    const { Client } = await import(pgPath);
    
    const client = new Client({ connectionString: uri });
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

    await client.end();
    return { driver: 'postgresql', collections: formattedData, timestamp: new Date().toISOString() };
  } catch (e: any) {
    return null;
  }
}

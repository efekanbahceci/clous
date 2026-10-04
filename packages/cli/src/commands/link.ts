import { ProjectConfigManager } from '../config/project.js';
import { CredentialsManager } from '../config/credentials.js';
import { logger } from '../utils/logger.js';
import { ansi } from '../utils/ansi.js';
import { ui } from '../utils/ui.js';

export interface LinkOptions {
  projectId: string;
  name?: string;
  orgId?: string;
  cwd?: string;
}

export async function linkCommand(options: LinkOptions): Promise<void> {
  const cwd = options.cwd || process.cwd();
  
  // 1. Check if already linked
  const existingConfig = ProjectConfigManager.load(cwd);
  if (existingConfig && existingConfig.projectId) {
    if (!options.projectId || existingConfig.projectId === options.projectId) {
      console.log('');
      ui.box({
        title: 'Already Linked',
        borderColor: ansi.blue,
        minWidth: 60,
        lines: [
          `This directory is already linked to: ${ansi.bold(existingConfig.projectId)}`,
          existingConfig.projectName ? `Project Name: ${existingConfig.projectName}` : null,
          ``,
          `No further action is required.`
        ].filter(line => line !== null) as string[]
      });
      console.log('');
      return;
    }
    // If they provided a DIFFERENT ID
    console.log('');
    ui.box({
      title: 'Already Linked to a Different Project',
      borderColor: ansi.yellow,
      minWidth: 60,
      lines: [
        `This directory is already linked to: ${ansi.bold(existingConfig.projectId)}`,
        `You requested to link to: ${ansi.bold(options.projectId)}`,
        ``,
        `If you want to link a different project, please run ${ansi.cyan('clous unlink')} first.`
      ].filter(line => line !== null) as string[]
    });
    console.log('');
    return;
  }

  if (!options.projectId) {
    throw new Error('Project ID is required to link a new project. Example: "clous link prj_123"');
  }

  const token = CredentialsManager.getToken();

  if (!token) {
    logger.warn('You are not currently logged in. Run "clous login" to authenticate with the Web Panel.');
    return;
  }

  // 2. Verify link with backend first
  let projectName = options.name;
  try {
    const apiBase = CredentialsManager.getApiUrl();
    const endpoint = `${apiBase}/api/projects/${options.projectId}/link`;
    const res = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({}),
    });
    
    if (!res.ok) {
      if (res.status === 404 || res.status === 401 || res.status === 403) {
        console.log('');
        ui.box({
          title: 'Invalid ID / Access Denied',
          borderColor: ansi.red,
          minWidth: 60,
          lines: [
            `Geçersiz ID: ${ansi.bold(options.projectId)}`,
            `This project does not exist, or you do not have permission to access it.`,
            `Please ensure you copied the correct Project ID from your dashboard.`
          ]
        });
        console.log('');
        return;
      }
      const errorText = await res.text();
      throw new Error(`API Error (${res.status}): ${errorText}`);
    }
    
    const data = await res.json().catch(() => ({}));
    if (data.project?.name) {
      projectName = data.project.name;
    }
  } catch (e: any) {
    logger.error(`Failed to connect to backend: ${e.message}`);
    return;
  }

  // 3. Auto-detect database key from .env
  let detectedEnvKey = 'DATABASE_URL';
  let detectedDriver: 'auto' | 'postgresql' | 'mongodb' | 'mysql' = 'auto';
  try {
    const fs = require('node:fs');
    const path = require('node:path');
    const envPath = path.join(cwd, '.env');
    if (fs.existsSync(envPath)) {
      const envContent = fs.readFileSync(envPath, 'utf8');
      if (envContent.includes('MONGODB_URI=')) {
        detectedEnvKey = 'MONGODB_URI';
        detectedDriver = 'mongodb';
      } else if (envContent.includes('POSTGRES_URL=')) {
        detectedEnvKey = 'POSTGRES_URL';
        detectedDriver = 'postgresql';
      } else if (envContent.includes('DATABASE_URL=')) {
        if (envContent.includes('postgres://') || envContent.includes('postgresql://')) {
          detectedDriver = 'postgresql';
        } else if (envContent.includes('mysql://')) {
          detectedDriver = 'mysql';
        } else if (envContent.includes('mongodb://') || envContent.includes('mongodb+srv://')) {
          detectedDriver = 'mongodb';
        }
      }
    }
  } catch (e) {
    // Ignore fs errors silently
  }

  // 4. Save config locally if verification passed (Scaffold the APM Manifest)
  ProjectConfigManager.save(
    {
      projectId: options.projectId,
      projectName: projectName,
      orgId: options.orgId,
      permissions: {
        trafficWatcher: true,
        envScanner: true,
        dbIntrospection: true
      },
      database: {
        driver: detectedDriver,
        envKey: detectedEnvKey
      }
    },
    cwd
  );

  const lines = [
    `Project ID    ${ansi.bold(options.projectId)}`,
  ];
  if (projectName) {
    lines.push(`Project Name  ${projectName}`);
  }
  lines.push(`Config File   ${ansi.dim('.clous/project.json')}`);
  lines.push(`Status        ${ansi.green('Linked to Web Panel workspace')}`);

  // 5. Auto-sync database schema on link
  try {
    const { introspectDatabase } = await import('../utils/db-inspector.js');
    console.log(`  ${ui.badge('SYNC')} Analyzing database schema...`);
    const schemaSnapshot = await introspectDatabase(cwd);
    
    if (schemaSnapshot) {
      const apiBase = CredentialsManager.getApiUrl();
      const schemaEndpoint = `${apiBase}/api/projects/${options.projectId}/schema`;
      
      const pushRes = await fetch(schemaEndpoint, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ dbSchema: schemaSnapshot }),
      });

      if (pushRes.ok) {
        lines.push('');
        lines.push(`${ansi.cyan('Introspection Configured:')}`);
        lines.push(`- Traffic Watcher : ${ansi.green('Active')}`);
        lines.push(`- Env Scanner     : ${ansi.green('Active')}`);
        lines.push(`- DB Schema       : ${ansi.green('Synced to Dashboard')} ${ansi.dim(`(Target: ${detectedEnvKey})`)}`);
      } else {
        lines.push('');
        lines.push(`${ansi.yellow('Introspection Partial:')}`);
        lines.push(`- DB Schema       : ${ansi.yellow('Sync failed (API Error)')} ${ansi.dim(`(${pushRes.status})`)}`);
      }
    } else {
      lines.push('');
      lines.push(`${ansi.yellow('Introspection Partial:')}`);
      lines.push(`- DB Schema       : ${ansi.yellow('Driver not found locally or connection failed')}`);
    }
  } catch (e: any) {
    lines.push('');
    lines.push(`${ansi.yellow('Introspection Error:')}`);
    lines.push(`- DB Schema       : ${ansi.yellow('Failed to analyze database')} ${ansi.dim(`(${e.message})`)}`);
  }

  console.log('');
  ui.box({
    title: 'Project Linked',
    borderColor: ansi.green,
    minWidth: 60,
    lines,
  });
  console.log('');
}

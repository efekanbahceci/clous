import fs from 'node:fs';
import path from 'node:path';
import { ProjectConfigManager } from '../config/project.js';
import { CredentialsManager } from '../config/credentials.js';
import { AuthService } from '../auth/auth-service.js';
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
  const requestedId = options.projectId?.trim();

  // 1. Check if this specific directory is already linked
  const existingConfig = ProjectConfigManager.load(cwd);
  if (existingConfig && existingConfig.projectId) {
    if (
      !requestedId ||
      existingConfig.projectId === requestedId ||
      existingConfig.clousId === requestedId
    ) {
      console.log('');
      ui.box({
        title: 'Already Linked',
        borderColor: ansi.blue,
        minWidth: 60,
        lines: [
          `This directory is already linked to: ${ansi.bold(existingConfig.projectId)}`,
          existingConfig.projectName ? `Project Name: ${existingConfig.projectName}` : null,
          ``,
          `No further action is required.`,
        ].filter((line) => line !== null) as string[],
      });
      console.log('');
      return;
    }

    // If they provided a DIFFERENT ID in an already-linked directory
    console.log('');
    ui.box({
      title: 'Already Linked to a Different Project',
      borderColor: ansi.yellow,
      minWidth: 60,
      lines: [
        `This directory is already linked to: ${ansi.bold(existingConfig.projectId)}`,
        `You requested to link to: ${ansi.bold(requestedId)}`,
        ``,
        `If you want to link a different project here, please run ${ansi.cyan('clous unlink')} first.`,
      ].filter((line) => line !== null) as string[],
    });
    console.log('');
    return;
  }

  if (!requestedId) {
    throw new Error('Project ID is required to link a new project. Example: "clous link <project-id>"');
  }

  // Verify active login session
  const auth = await AuthService.whoami();
  const token = CredentialsManager.getToken();

  if (!auth.loggedIn || !token) {
    logger.warn('You are not currently logged in. Run "clous login" to authenticate with the Web Panel.');
    return;
  }

  // 2. Verify link with backend first
  let projectName = options.name;
  let canonicalProjectId = requestedId;
  let projectClousId: string | undefined;
  try {
    const apiBase = (auth.apiUrl || CredentialsManager.getApiUrl()).replace(/\/+$/, '');
    const endpoint = `${apiBase}/api/projects/${encodeURIComponent(requestedId)}/link`;
    const res = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
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
            `Project ID    ${ansi.bold(requestedId)}`,
            `Account       ${ansi.cyan(auth.profile?.email || 'authenticated user')}`,
            ``,
            `This project does not exist under your account, or you do not have permission to access it.`,
            `Please ensure you copied the correct Project ID from your dashboard.`,
          ],
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
    if (data.project?.id) {
      canonicalProjectId = data.project.id;
    }
    if (data.project?.clousId) {
      projectClousId = data.project.clousId;
    }
  } catch (e: any) {
    logger.error(`Failed to connect to backend: ${e.message}`);
    return;
  }

  // 3. Auto-detect database key from .env
  let detectedEnvKey = 'DATABASE_URL';
  let detectedDriver: 'auto' | 'postgresql' | 'mongodb' | 'mysql' = 'auto';
  try {
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
  } catch {
    // Ignore fs errors silently
  }

  // 4. Save config locally in THIS project's .clous/project.json
  ProjectConfigManager.save(
    {
      projectId: canonicalProjectId,
      clousId: projectClousId,
      projectName: projectName,
      orgId: options.orgId,
      linkedUserId: auth.profile?.id,
      permissions: {
        trafficWatcher: true,
        envScanner: true,
        dbIntrospection: true,
      },
      database: {
        driver: detectedDriver,
        envKey: detectedEnvKey,
      },
    },
    cwd
  );

  const lines = [
    `Project ID    ${ansi.bold(canonicalProjectId)}`,
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
      const apiBase = (auth.apiUrl || CredentialsManager.getApiUrl()).replace(/\/+$/, '');
      const schemaEndpoint = `${apiBase}/api/projects/${encodeURIComponent(canonicalProjectId)}/schema`;
      
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

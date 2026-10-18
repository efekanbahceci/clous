import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { initCommand } from '../src/commands/init.js';
import { generateCommand } from '../src/commands/generate.js';
import { validateCommand } from '../src/commands/validate.js';
import { statusCommand } from '../src/commands/status.js';
import { linkCommand } from '../src/commands/link.js';
import { CredentialsManager } from '../src/config/credentials.js';
import { ProjectConfigManager } from '../src/config/project.js';

describe('@clous/cli', () => {
  let tempDir: string;

  beforeEach(() => {
    const baseDir = path.resolve(__dirname, '../.tmp-test');
    if (!fs.existsSync(baseDir)) {
      fs.mkdirSync(baseDir, { recursive: true });
    }
    tempDir = fs.mkdtempSync(path.join(baseDir, 'cli-test-'));
  });

  afterEach(() => {
    vi.restoreAllMocks();
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  it('init command generates starter schema.ts', async () => {
    await initCommand({ cwd: tempDir });

    const schemaPath = path.join(tempDir, 'schema.ts');
    expect(fs.existsSync(schemaPath)).toBe(true);

    const content = fs.readFileSync(schemaPath, 'utf8');
    expect(content).toContain("table('users'");
    expect(content).toContain("table('posts'");
    expect(content).toContain("export const appSchema = schema(");
  });

  it('generate command compiles schema.ts into SQL, types, and openapi spec', async () => {
    // 1. Initialize schema in tempDir
    await initCommand({ cwd: tempDir });

    // 2. Run generate
    const { sqlPath, dtsPath, openApiPath } = await generateCommand({
      cwd: tempDir,
      outDir: 'generated',
      silent: true,
    });

    expect(fs.existsSync(sqlPath)).toBe(true);
    expect(fs.existsSync(dtsPath)).toBe(true);
    expect(fs.existsSync(openApiPath)).toBe(true);

    const sql = fs.readFileSync(sqlPath, 'utf8');
    expect(sql).toContain('CREATE TABLE IF NOT EXISTS "users"');
    expect(sql).toContain('ENABLE ROW LEVEL SECURITY');

    const dts = fs.readFileSync(dtsPath, 'utf8');
    expect(dts).toContain('export interface UsersRow');
    expect(dts).toContain('export interface PostsRow');

    const openApi = JSON.parse(fs.readFileSync(openApiPath, 'utf8'));
    expect(openApi.openapi).toBe('3.0.3');
    expect(openApi.paths['/api/users']).toBeDefined();
  });

  it('validate command passes on valid schema', async () => {
    await initCommand({ cwd: tempDir });
    await expect(validateCommand({ cwd: tempDir })).resolves.not.toThrow();
  });

  it('credentials manager stores and clears token, and rejects fake dev_user sessions', () => {
    const origDir = process.env.CLOUS_CONFIG_DIR;
    const origFile = process.env.CLOUS_CREDENTIALS_FILE;
    const configDir = path.join(tempDir, 'config');
    const credsFile = path.join(configDir, 'credentials.json');
    process.env.CLOUS_CONFIG_DIR = configDir;
    process.env.CLOUS_CREDENTIALS_FILE = credsFile;

    try {
      CredentialsManager.save({
        token: 'test_token_123',
        apiUrl: 'https://custom.clous.dev',
        profile: { id: 'user_real_1', email: 'test@example.com' },
      });

      const loaded = CredentialsManager.load();
      expect(loaded.token).toBe('test_token_123');
      expect(loaded.apiUrl).toBe('https://custom.clous.dev');
      expect(loaded.profile?.email).toBe('test@example.com');

      // Fake dev_user session should be automatically cleared on load
      CredentialsManager.save({
        token: 'clous_fake_dev',
        apiUrl: 'https://clous.dev',
        profile: { id: 'dev_user', email: 'developer@clous.local' },
      });
      const afterFake = CredentialsManager.load();
      expect(afterFake.token).toBeUndefined();

      CredentialsManager.clear();
      const afterClear = CredentialsManager.load();
      expect(afterClear.token).toBeUndefined();
    } finally {
      if (origDir === undefined) delete process.env.CLOUS_CONFIG_DIR;
      else process.env.CLOUS_CONFIG_DIR = origDir;
      if (origFile === undefined) delete process.env.CLOUS_CREDENTIALS_FILE;
      else process.env.CLOUS_CREDENTIALS_FILE = origFile;
    }
  });

  it('project config manager links and unlinks project strictly per directory', async () => {
    const origDir = process.env.CLOUS_CONFIG_DIR;
    const origFile = process.env.CLOUS_CREDENTIALS_FILE;
    const configDir = path.join(tempDir, 'global-config');
    const credsFile = path.join(configDir, 'credentials.json');
    process.env.CLOUS_CONFIG_DIR = configDir;
    process.env.CLOUS_CREDENTIALS_FILE = credsFile;

    const projectXDir = path.join(tempDir, 'project-x');
    const projectYDir = path.join(tempDir, 'project-x', 'sub-project-y');
    const projectZDir = path.join(tempDir, 'project-z');
    fs.mkdirSync(projectXDir, { recursive: true });
    fs.mkdirSync(projectYDir, { recursive: true });
    fs.mkdirSync(projectZDir, { recursive: true });

    try {
      // Simulate active login session across the machine
      CredentialsManager.save({
        token: 'clous_user_abc',
        apiUrl: 'https://clous.dev',
        profile: { id: 'user_abc', email: 'efekan@clous.dev', name: 'Efekan' },
      });

      vi.spyOn(globalThis, 'fetch').mockImplementation(async (input: any) => {
        const url = String(input);
        if (url.endsWith('/api/cli/verify')) {
          return new Response(
            JSON.stringify({
              valid: true,
              profile: { id: 'user_abc', email: 'efekan@clous.dev', name: 'Efekan' },
            }),
            { status: 200, headers: { 'Content-Type': 'application/json' } }
          );
        }
        if (url.endsWith('/api/projects/prj_x/link')) {
          return new Response(
            JSON.stringify({
              ok: true,
              isLinked: true,
              project: { id: '65f000000000000000000001', clousId: 'prj_x', name: 'Project X' },
            }),
            { status: 200, headers: { 'Content-Type': 'application/json' } }
          );
        }
        if (url.endsWith('/api/projects/prj_z/link')) {
          return new Response(
            JSON.stringify({
              ok: true,
              isLinked: true,
              project: { id: '65f000000000000000000002', clousId: 'prj_z', name: 'Project Z' },
            }),
            { status: 200, headers: { 'Content-Type': 'application/json' } }
          );
        }
        return new Response(JSON.stringify({ error: 'Not found' }), { status: 404 });
      });

      // 1. Link Project X
      await linkCommand({ projectId: 'prj_x', cwd: projectXDir });
      const loadedX = ProjectConfigManager.load(projectXDir);
      expect(loadedX?.projectId).toBe('65f000000000000000000001');
      expect(loadedX?.clousId).toBe('prj_x');
      expect(loadedX?.projectName).toBe('Project X');

      // 2. Switch to Project Y (nested) and Project Z (sibling): neither should inherit Project X's link!
      expect(ProjectConfigManager.load(projectYDir)).toBeNull();
      expect(ProjectConfigManager.load(projectZDir)).toBeNull();

      // Verify `clous about` / `clous status` in Project Z shows Active auth + Not linked
      const logs: string[] = [];
      const logSpy = vi.spyOn(console, 'log').mockImplementation((...args) => {
        logs.push(args.join(' '));
      });
      await statusCommand({ cwd: projectZDir });
      logSpy.mockRestore();

      const combinedStatusOutput = logs.join('\n');
      expect(combinedStatusOutput).toContain('Active');
      expect(combinedStatusOutput).toContain('efekan@clous.dev');
      expect(combinedStatusOutput).toContain('Not linked');

      // 3. Link Project Z independently without affecting Project X
      await linkCommand({ projectId: 'prj_z', cwd: projectZDir });
      const loadedZ = ProjectConfigManager.load(projectZDir);
      expect(loadedZ?.projectId).toBe('65f000000000000000000002');
      expect(loadedZ?.projectName).toBe('Project Z');

      // Project X is STILL linked to Project X
      expect(ProjectConfigManager.load(projectXDir)?.projectId).toBe('65f000000000000000000001');
    } finally {
      if (origDir === undefined) delete process.env.CLOUS_CONFIG_DIR;
      else process.env.CLOUS_CONFIG_DIR = origDir;
      if (origFile === undefined) delete process.env.CLOUS_CREDENTIALS_FILE;
      else process.env.CLOUS_CREDENTIALS_FILE = origFile;
    }
  });
});

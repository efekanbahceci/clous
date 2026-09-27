import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { initCommand } from '../src/commands/init.js';
import { generateCommand } from '../src/commands/generate.js';
import { validateCommand } from '../src/commands/validate.js';
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
    const outDir = path.join(tempDir, 'generated');
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

  it('credentials manager stores and clears token', () => {
    const origDir = process.env.CLOUS_CONFIG_DIR;
    process.env.CLOUS_CONFIG_DIR = path.join(tempDir, 'config');

    try {
      CredentialsManager.save({
        token: 'test_token_123',
        apiUrl: 'https://custom.clous.dev',
        profile: { email: 'test@example.com' },
      });

      const loaded = CredentialsManager.load();
      expect(loaded.token).toBe('test_token_123');
      expect(loaded.apiUrl).toBe('https://custom.clous.dev');
      expect(loaded.profile?.email).toBe('test@example.com');

      CredentialsManager.clear();
      const afterClear = CredentialsManager.load();
      expect(afterClear.token).toBeUndefined();
    } finally {
      process.env.CLOUS_CONFIG_DIR = origDir;
    }
  });

  it('project config manager links and unlinks project', () => {
    ProjectConfigManager.save(
      {
        projectId: 'prj_test_123',
        projectName: 'Test Project',
      },
      tempDir
    );

    const loaded = ProjectConfigManager.load(tempDir);
    expect(loaded).toBeDefined();
    expect(loaded?.projectId).toBe('prj_test_123');
    expect(loaded?.projectName).toBe('Test Project');

    const unlinked = ProjectConfigManager.unlink(tempDir);
    expect(unlinked).toBe(true);
    expect(ProjectConfigManager.load(tempDir)).toBeNull();
  });
});

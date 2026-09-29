import { parseArgs } from 'node:util';
import { initCommand } from './commands/init.js';
import { generateCommand } from './commands/generate.js';
import { validateCommand } from './commands/validate.js';
import { devCommand } from './commands/dev.js';
import { loginCommand } from './commands/login.js';
import { logoutCommand } from './commands/logout.js';
import { whoamiCommand } from './commands/whoami.js';
import { linkCommand } from './commands/link.js';
import { statusCommand } from './commands/status.js';
import { logger } from './utils/logger.js';
import { ansi } from './utils/ansi.js';
import { ui } from './utils/ui.js';

const VERSION = '0.1.0';

export async function runCli(argv: string[] = process.argv.slice(2)): Promise<void> {
  const { values, positionals } = parseArgs({
    args: argv,
    options: {
      help: { type: 'boolean', short: 'h' },
      version: { type: 'boolean', short: 'v' },
      schema: { type: 'string', short: 's' },
      out: { type: 'string', short: 'o' },
      force: { type: 'boolean', short: 'f' },
      token: { type: 'string', short: 't' },
      'api-url': { type: 'string' },
      'project-id': { type: 'string', short: 'p' },
      name: { type: 'string', short: 'n' },
      port: { type: 'string' },
    },
    allowPositionals: true,
    strict: false,
  });

  if (values.version) {
    console.log(`clous v${VERSION}`);
    return;
  }

  const command = positionals[0]?.toLowerCase();

  if (values.help || !command || command === 'help') {
    await printHelp();
    return;
  }

  try {
    switch (command) {
      // Local Commands (Offline / No Auth Needed)
      case 'init':
        await initCommand({
          force: Boolean(values.force),
        });
        break;

      case 'generate':
      case 'gen':
        await generateCommand({
          schema: values.schema as string | undefined,
          outDir: values.out as string | undefined,
        });
        break;

      case 'validate':
      case 'check':
        await validateCommand({
          schema: values.schema as string | undefined,
        });
        break;

      case 'dev':
      case 'watch':
        await devCommand({
          schema: values.schema as string | undefined,
          outDir: values.out as string | undefined,
        });
        break;

      // Cloud Commands (Auth & Synchronization)
      case 'login':
        await loginCommand({
          token: values.token as string | undefined,
          apiUrl: values['api-url'] as string | undefined,
          port: values.port ? parseInt(values.port as string, 10) : undefined,
        });
        break;

      case 'logout':
        await logoutCommand();
        break;

      case 'whoami':
        await whoamiCommand();
        break;

      case 'link':
        if (!values['project-id']) {
          throw new Error('Option --project-id <id> is required for "clous link".');
        }
        await linkCommand({
          projectId: values['project-id'] as string,
          name: values.name as string | undefined,
        });
        break;

      case 'status':
        await statusCommand();
        break;

      default:
        logger.error(`Unknown command: "${command}". Run "clous --help" for available commands.`);
        process.exitCode = 1;
        break;
    }
  } catch (err: any) {
    logger.error(err.message || String(err));
    process.exitCode = 1;
  }
}

async function printHelp(): Promise<void> {
  await ui.animateBanner(VERSION);

  console.log(`  ${ansi.bold('USAGE:')}
    $ clous <command> [options]

  ${ansi.bold('LOCAL COMMANDS (Offline - No login required):')}
    ${ansi.cyan('init')}                    Initialize a new Clous project with a starter schema
    ${ansi.cyan('generate')}, ${ansi.cyan('gen')}         Compile schema into SQL DDL, TypeScript types, and OpenAPI spec
    ${ansi.cyan('validate')}                Check schema structure, relations, and RLS policies
    ${ansi.cyan('dev')}, ${ansi.cyan('watch')}            Watch schema file for changes and recompile automatically

  ${ansi.bold('CLOUD COMMANDS (Auth & Web Panel Sync):')}
    ${ansi.cyan('login')}                   Authenticate CLI with the Clous Web Panel
    ${ansi.cyan('logout')}                  Log out and remove local credentials
    ${ansi.cyan('whoami')}                  Display active authenticated user and session
    ${ansi.cyan('link')}                    Link local directory to a remote Web Panel project
    ${ansi.cyan('status')}                  Show auth, project linking, and schema status

  ${ansi.bold('OPTIONS:')}
    -s, --schema <path>       Path to schema file (default: schema.ts)
    -o, --out <dir>           Output directory for generated files (default: generated)
    -t, --token <token>       Access token for headless login (CI/CD)
    -p, --project-id <id>     Project ID for linking
    -f, --force               Overwrite existing files without prompting
    -h, --help                Display help information
    -v, --version             Display CLI version

  ${ansi.bold('EXAMPLES:')}
    $ clous init
    $ clous generate --out ./src/generated
    $ clous dev
    $ clous login --token clous_pat_...
    $ clous link --project-id prj_123456
    $ clous status
`);
}

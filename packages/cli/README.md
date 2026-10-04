# @clous/cli

The official command-line interface for Clous. Compile schemas, generate type-safe database SDKs, and synchronize with the Clous Web Panel.

---

## Installation

```bash
npm install -g @clous/cli
# or locally inside your project:
npm install -D @clous/cli
```

Node.js 20 or higher is required.

---

## Local Commands (Offline / No Login Required)

These commands work 100% offline without an internet connection or Clous account.

### 1. Initialize a Project

Creates a starter `schema.ts` file with users, posts, foreign keys, and Row Level Security (RLS) policies:

```bash
clous init
```

### 2. Compile Schema (Code & DDL Generation)

Reads `schema.ts` and generates:
- PostgreSQL DDL with RLS (`generated/schema.sql`)
- TypeScript type definitions (`generated/db-types.d.ts`)
- OpenAPI 3.0 specification (`generated/openapi.json`)

```bash
clous generate
# Custom schema path or output directory:
clous generate --schema ./src/schema.ts --out ./src/generated
```

### 3. Validate Schema

Performs semantic and relation checks on your schema file without emitting files:

```bash
clous validate
```

### 4. Watch Mode (Automatic Recompilation)

Watches your `schema.ts` file and recompiles immediately upon save:

```bash
clous dev
```

---

## Cloud Commands (Web Panel Synchronization)

These commands connect your local development workflow to the Clous Web Panel.

### 1. Login

Authenticate via browser or with a Personal Access Token:

```bash
# Interactive browser login:
clous login

# Headless / CI/CD login:
clous login --token clous_pat_xxxxxxxxxxxxxxxx
```

### 2. Whoami

Inspect your active authenticated session:

```bash
clous whoami
```

### 3. Link Project

Link your local project directory to a remote project created on the Web Panel:

```bash
clous link --project-id prj_123456 --name "My Project"
```

### 4. Status

Display the full environment status including authentication, linked project, and local schema:

```bash
clous status
```

### 5. Logout

Clear stored credentials from your local machine:

```bash
clous logout
```

---

## Environment Variables

For automated CI/CD pipelines (GitHub Actions, GitLab CI), you can configure the CLI without interactive prompts:

| Variable | Description |
|---|---|
| `CLOUS_ACCESS_TOKEN` | Personal access token for authenticating cloud commands |
| `CLOUS_API_URL` | Override Web Panel / Control Plane API URL (default: `https://clous.dev`) |
| `CLOUS_CONFIG_DIR` | Custom directory for credentials storage |

---

## License

MIT

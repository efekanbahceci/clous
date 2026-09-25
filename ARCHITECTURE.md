# Clous Architecture & System Design

**Clous** is a next-generation Backend-as-a-Service (BaaS) and Type-Safe ORM platform. It unifies the robust PostgreSQL and authentication infrastructure of **Supabase** with the developer experience (DX) and automated end-to-end type generation of **Prisma**.

---

## 1. System Topology Overview

```
                      +---------------------------------------+
                      |       Developer / Frontend App        |
                      +---------------------------------------+
                                          |
                        HTTPS (JWT) / CLI / SDK Calls
                                          v
                      +---------------------------------------+
                      |   Dynamic API Gateway (Caddy Server)  |
                      |   - WAF & Rate Limiting               |
                      |   - Subdomain Routing (tenant-*.clous)|
                      |   - SSL / mTLS Termination            |
                      +---------------------------------------+
                                  /               \
       Admin Control Flow (VPC)  /                 \  Data Traffic (Isolated)
                                v                   v
          +-------------------------+      +-------------------------+
          | Control Plane (Master)  |      |   Data Plane (Tenant)   |
          | - Master API            |      | - Tenant Core Engine    |
          | - Master Database       |      | - Isolated Postgres DB  |
          | - Orchestration Engine  |      | - Container / MicroVM   |
          +-------------------------+      +-------------------------+
```

---

## 2. Core Engine: Compiler Pipeline

The heart of Clous is an isolated, compiler-driven TypeScript module that transforms declarative schema definitions into physical databases, client SDKs, and dynamic runtime APIs.

```
+-----------------------------------------------------------------------+
|                             CLOUS CORE                                |
|                                                                       |
|  [Stage 1: Builder]  ==>  [Stage 2: IR / AST]  ==>  [Stage 3: Emitters]|
|  Fluent TypeScript         Validated Abstract        - PostgresSql    |
|  & Zod Schemas             Syntax Tree               - TsType (.d.ts) |
|                                                      - Runtime API    |
+-----------------------------------------------------------------------+
```

### Stage 1: Fluent Builder
- Developer-friendly API (`table`, `uuid`, `text`, `integer`, `timestamp`, `policy`).
- Instant type inference and syntax checking.

### Stage 2: Intermediate Representation (IR / AST)
- Canonical data model representing schemas, tables, columns, indexes, foreign keys, and security policies.
- Validated via strict Zod schemas to guarantee structural validity and prevent malformed inputs.
- Cross-table semantic checks (foreign key target resolution, uniqueness).

### Stage 3: Emitters (Visitor Pattern)
- **`PostgresSqlEmitter`**: Translates AST nodes into PostgreSQL DDL (`CREATE TABLE`, constraints, indexes) and declarative Row Level Security (`ENABLE ROW LEVEL SECURITY`, `CREATE POLICY`).
- **`TsTypeEmitter`**: Generates strongly typed TypeScript definitions (`Row`, `Insert`, `Update`, `Database` mapping) for frontend/backend SDKs.
- **`ApiEmitter`** *(Phase 2)*: Scaffolds Fastify dynamic CRUD routes mapped to database operations.

---

## 3. Control Plane vs. Data Plane

| Feature | Control Plane (Master System) | Data Plane (Tenant System) |
|---|---|---|
| **Role** | Platform administration & billing | Application runtime & data storage |
| **Database** | Master PostgreSQL (users, plans, metadata) | Isolated Tenant PostgreSQL |
| **Access** | Internal VPC only (Admin Port) | API Gateway (JWT-authenticated) |
| **Isolation** | Shared Multi-tenant SaaS DB | Dedicated Container / MicroVM per project |

### Schema Change Execution Flow:
1. Developer edits schema via Web Dashboard or CLI.
2. Master API authenticates ownership and serializes schema payload to JSON.
3. Master API forwards instruction over private VPC admin port to the project's Core Engine.
4. Core Engine compiles AST into DDL and applies changes inside the tenant's dedicated PostgreSQL database.

---

## 4. Multi-Tenant Orchestration

- **Container Isolation**: Each project runs in a dedicated Docker or Kubernetes container / pod, preventing noisy neighbor issues and cross-tenant data leaks.
- **Hardware Virtualization (Scale)**: In high-security environments, tenant workloads execute inside hardware-isolated **AWS Firecracker** MicroVMs.
- **Dynamic Routing**: **Caddy Server** dynamically resolves subdomains (`project-id.clous.io`) to internal tenant endpoints with instant automatic TLS.
- **Scale-to-Zero**: Inactive tenant databases can be paused and revived upon receiving HTTP requests.

---

## 5. Security Architecture

### Macro Security (Infrastructure & Network)
- **Zero-Trust VPC & mTLS**: Inter-service communication between Master API and tenant nodes is fully encrypted and unexposed to public networks.
- **Gateway Defense**: Edge rate limiting, DDoS mitigation, and Web Application Firewall (WAF).

### Micro Security (Data & Application Layer)
- **Declarative PostgreSQL RLS**: Permissions enforced directly in the database engine via `CREATE POLICY`.
- **JWT Session Context**: JWT claims (e.g. `auth.uid()`) are set as session variables (`set_config('request.jwt.claim.sub', ...)`) prior to executing queries.
- **Injection Proof**: AST validation + typed query parameterization make SQL injection structurally impossible.

---

## 6. Implementation Roadmap

- [x] **Phase 1: Core Engine Prototype (Local-First)**
  - [x] AST & IR type specifications.
  - [x] Strict Zod validation schemas for AST.
  - [x] Fluent Builder API with relationships and declarative RLS.
  - [x] `PostgresSqlEmitter` (DDL, Indexes, RLS Policies).
  - [x] `TsTypeEmitter` (Row, Insert, Update, Database interfaces).
  - [x] Vitest unit test suite (100% passing).
- [ ] **Phase 2: Type Safety & Runtime API**
  - [ ] `ts-morph` physical `.d.ts` file generator.
  - [ ] Fastify + `pg` dynamic CRUD runtime server with JWT auth and RLS session propagation.
- [ ] **Phase 3: Developer CLI & Local Docker**
  - [ ] CLI with `cac` (`clous init`, `clous generate`, `clous dev`).
  - [ ] Local single-command Docker Compose stack.
- [ ] **Phase 4: Control Plane & Master System**
  - [ ] Master DB, Next.js/React Dashboard, Stripe billing integration.
- [ ] **Phase 5: Cloud Orchestration & Gateway**
  - [ ] Dynamic Caddy reverse proxy integration.
  - [ ] Automated container/MicroVM provisioning.

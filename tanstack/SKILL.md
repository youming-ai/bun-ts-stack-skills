---
name: tanstack
description: Full-stack TypeScript conventions for apps on the Bun + TanStack Start ecosystem, deployed to Cloudflare Workers. Covers scaffolding, layout, integrations, config, and deploy for the canonical stack of Bun (dev tooling), TanStack Start, Vite, Hono, Drizzle ORM, self-hosted PostgreSQL via Cloudflare Hyperdrive, Better Auth, Tailwind v4, shadcn/ui, TanStack Form, Zod, Resend, pino, Sentry, lefthook, GitHub Actions, Biome, bun test, and wrangler. Use whenever the user is scaffolding, configuring, writing code for, or deploying a project mentioning ANY of these — including "set up a new project", "add auth", "send emails", "add logging", "rate limit", "CI pipeline", "Drizzle schema", "mount Hono", "deploy to Cloudflare", "Workers", "Hyperdrive", "my stack", or "this project" in a Bun + TanStack context. Trigger even when only a subset is mentioned, since it is the project's canonical stack and other choices should be checked against it.
---

# TanStack Bun Stack

Conventions for full-stack TypeScript apps on Bun + TanStack Start, deployed to Cloudflare Workers. Source of truth for stack choices, layout, integrations, and deploy. Deviate only with explicit reason.

## Stack

| Layer          | Choice                                                  |
| -------------- | ------------------------------------------------------- |
| Dev runtime    | Bun (package manager, test, scripts)                    |
| Prod runtime   | Cloudflare Workers (V8 isolate)                         |
| Language       | TypeScript (strict)                                     |
| Framework      | TanStack Start                                          |
| Build          | Vite                                                    |
| API            | Hono                                                    |
| ORM            | Drizzle + Drizzle Kit                                   |
| Database       | Self-hosted PostgreSQL via Cloudflare Hyperdrive        |
| DB driver      | `postgres` (postgres.js) over Workers TCP               |
| KV             | Cloudflare KV (Better Auth secondary storage, edge cache) |
| Auth           | Better Auth                                             |
| CSS            | Tailwind v4 (`@tailwindcss/vite`)                       |
| UI             | shadcn/ui + lucide-react                                |
| Forms          | TanStack Form                                           |
| Validation     | Zod                                                     |
| Email          | Resend + React Email                                    |
| Logging        | pino + `hono-pino`                                      |
| Monitoring     | Sentry (`@sentry/cloudflare` + `@sentry/tanstackstart-react`) |
| Security       | `hono/cors`, `hono/secure-headers`, KV-backed rate limiter |
| Lint/Format    | Biome                                                   |
| Git hooks      | lefthook                                                |
| Test           | `bun test`                                              |
| CI/CD          | GitHub Actions + `wrangler deploy`                      |
| Deploy         | Cloudflare Workers                                      |

### Non-negotiables

- Bun is the dev runtime: package manager, test runner, script runner. Never `npm` / `pnpm` / `yarn` / `node`.
- Production runs on **Cloudflare Workers** — a V8 isolate, not Node. Runtime code must be Workers-compatible: Web-standard APIs (`fetch`, Web Crypto, Streams), no Node built-ins unless `nodejs_compat` is enabled.
- Prefer Web-standard APIs over Bun-specific ones (`Bun.password`, `bun:sqlite`, `Bun.s3`) in runtime code, so the same code runs under Bun (dev/test) and Workers (prod). Better Auth hashes via Web Crypto — no `bcrypt`/`argon2` needed.
- TypeScript `strict: true` everywhere.
- Do not install: `dotenv`, `ts-node`, `tsx`, `nodemon`, `jest`, `bcrypt`, `argon2`, `node-fetch`, `eslint`, `prettier`, `nodemailer`, `husky`, `pre-commit`, `winston`, `bunyan`.
- Default to `bun test`; use `vitest` only for Cloudflare Workers integration tests that need the real Workers runtime or bindings. Default to `postgres` (postgres.js) with Drizzle; use `pg` only when library interop or an official Cloudflare path requires it.

## Architecture

```
                      Build time                          Request time
                      ──────────                          ────────────

  Routes (SSG)  ──► prerender ──► flat HTML ───────────►  Cloudflare CDN  ──►  Browser
  (vite plugin prerender)                                  (no server run)

  Routes (SSR)  ──────────────────────────────────────►  Cloudflare Workers
  (default)                                                     │
                                                          React server render
                                                                │
                                                          stream HTML  ────────►  Browser
                                                                ▲
                                                                │  secrets = Worker bindings (c.env)
                                                                │
  Component ──► createServerFn stub ──typed fetch POST──►  Worker endpoint
  (co-located, same file)                                       │
                                                          server fn / Hono handler
                                                                │
                                                                ▼
                                                          Drizzle ──► Hyperdrive ──► PostgreSQL
                                                          Better Auth               (self-hosted)
```

- CRUD → **server functions** co-located with components.
- Middleware, OpenAPI, RPC, external API surface → **Hono** at `/api/*`.
- **Better Auth** plugs into Hono as handler, Drizzle as schema.
- One **Zod schema** per concept in `src/schemas/`, shared by Hono / Form / Drizzle.
- Secrets come from **Worker bindings** (`c.env`), never `process.env` (empty on Workers unless `nodejs_compat`). Public values use the `VITE_` prefix.
- Bindings (Hyperdrive, KV, secrets) exist only at **request time** — build the DB client and Better Auth per request, never at module top level. KV is for session/cache acceleration and approximate rate-limit state; anything needing immediate revocation, atomic counters, or strong consistency stays in Postgres or a Durable Object.

### Rendering strategy

TanStack Start supports per-route rendering:

| Route type | Mode | How |
|---|---|---|
| Data-independent (landing, blog, about) | Static (SSG) | `tanstackStart({ prerender: { enabled: true } })` in `vite.config.ts` (per-page via `pages`); needs `@tanstack/react-start` ≥ 1.138 |
| Per-request data (dashboard, account) | Server (SSR) | default |
| Purely client-rendered (SPA fallback) | CSR | `ssr: false` route option in `createFileRoute(...)({ ... })` |

Prerendered routes serve flat HTML from the Cloudflare CDN with no Worker invocation. Server functions can also be cached at build time — see [TanStack docs on Static Server Functions](https://tanstack.com/start/latest/docs/framework/react/guide/static-server-functions).

## Project structure

```
src/
├── routes/
│   ├── __root.tsx
│   ├── index.tsx
│   └── api/$.ts                  # catch-all → Hono
├── server/
│   ├── hono.ts                   # Hono app + sub-routers
│   ├── routers/                  # posts.ts, users.ts, ...
│   └── middleware/
├── db/
│   ├── index.ts                  # Drizzle client factory (from Hyperdrive binding)
│   ├── schema.ts                 # business tables
│   └── auth-schema.ts            # Better Auth (CLI-generated, do not edit)
├── lib/
│   ├── auth.ts, auth-client.ts
│   ├── email.ts                  # Resend wrapper
│   └── logger.ts                 # pino
├── emails/                       # React Email templates
├── schemas/                      # shared Zod schemas
├── components/{ui,forms}/
├── styles/app.css                # @import "tailwindcss"
└── router.tsx
drizzle/                          # generated migrations
.github/workflows/ci.yml
biome.json, drizzle.config.ts, lefthook.yml, vite.config.ts, wrangler.toml
```

## Setup

```bash
bun create tsrouter-app@latest my-app && cd my-app

# Runtime
bun add hono drizzle-orm postgres better-auth zod @tanstack/react-form
bun add resend react-email @react-email/components
bun add pino hono-pino
bun add @sentry/cloudflare @sentry/tanstackstart-react
bun add tailwindcss @tailwindcss/vite

# Dev
bun add -d drizzle-kit @biomejs/biome lefthook wrangler @cloudflare/workers-types
bun add -d @cloudflare/vite-plugin @vitejs/plugin-react

# Init
bunx shadcn@latest init
bunx biome init
bunx lefthook install

# After writing src/lib/auth.ts
bunx @better-auth/cli generate --output src/db/auth-schema.ts

# Migrations connect directly to Postgres (DATABASE_URL), NOT through Hyperdrive
bunx drizzle-kit generate && bunx drizzle-kit migrate

# Provision Hyperdrive over your self-hosted Postgres (returns an id for wrangler.toml)
bunx wrangler hyperdrive create my-app-db --connection-string="postgres://user:pass@host:5432/db"

# KV namespace for sessions + edge cache (returns an id for wrangler.toml)
bunx wrangler kv namespace create KV
```

## Integration patterns

### Mount Hono inside Start

`src/routes/api/$.ts`:

```ts
import { createFileRoute } from '@tanstack/react-router'
import { env } from 'cloudflare:workers'
import { app } from '~/server/hono'

// Pass the Workers env as the second arg so Hono handlers get `c.env` (bindings, secrets)
const handler = ({ request }: { request: Request }) => app.fetch(request, env)

export const Route = createFileRoute('/api/$')({
  server: {
    handlers: { GET: handler, POST: handler, PUT: handler, DELETE: handler, PATCH: handler },
  },
})
```

`src/server/hono.ts` — see *Security middleware* for the production version that wires CORS, secure headers, and rate limiting.

### Drizzle over Hyperdrive

Bindings aren't available at module load on Workers — build the client per request from the Hyperdrive binding's connection string. A factory keeps one code path for Bun (dev) and Workers (prod).

```ts
// src/db/index.ts
import { drizzle } from 'drizzle-orm/postgres-js'
import postgres from 'postgres'
import * as schema from './schema'
import * as authSchema from './auth-schema'

// connStr: env.HYPERDRIVE.connectionString on Workers, process.env.DATABASE_URL in dev
export function createDb(connStr: string) {
  const client = postgres(connStr, { prepare: false, max: 5 })
  return drizzle(client, { schema: { ...schema, ...authSchema } })
}
export type DB = ReturnType<typeof createDb>
```

```ts
// drizzle.config.ts — migrations connect DIRECTLY to Postgres, never through Hyperdrive
import { defineConfig } from 'drizzle-kit'

export default defineConfig({
  schema: ['./src/db/schema.ts', './src/db/auth-schema.ts'],
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: { url: process.env.DATABASE_URL! },
})
```

Workflow: `bunx drizzle-kit generate` → `migrate`; `studio` for GUI.

For routes that make several DB round trips per request, consider Smart Placement so the Worker can run closer to the database. Do not enable it blindly on asset-heavy or mostly-static Workers; split a DB-heavy backend Worker behind a service binding if frontend latency starts to suffer.

### Better Auth

Better Auth needs the DB, and both are request-scoped on Workers — wrap them in a factory.

```ts
// src/lib/auth.ts
import { betterAuth } from 'better-auth'
import { drizzleAdapter } from 'better-auth/adapters/drizzle'
import type { DB } from '~/db'
import { sendEmail } from '~/lib/email'
import { ResetPasswordEmail, VerifyEmail } from '~/emails'

// env is the Workers bindings object (`c.env`) — pass it straight through
export function createAuth(db: DB, env: Env) {
  return betterAuth({
    database: drizzleAdapter(db, { provider: 'pg' }),
    // KV is secondary storage for session/cache acceleration and approximate rate-limit state.
    // Keep strong-consistency decisions in Postgres or a Durable Object.
    secondaryStorage: {
      get: (key) => env.KV.get(key),
      set: (key, value, ttl) => env.KV.put(key, value, ttl ? { expirationTtl: ttl } : undefined),
      delete: (key) => env.KV.delete(key),
    },
    secret: env.BETTER_AUTH_SECRET,
    baseURL: env.PUBLIC_ORIGIN,
    emailAndPassword: {
      enabled: true,
      requireEmailVerification: true,
      sendResetPassword: async ({ user, url }) =>
        sendEmail({ to: user.email, subject: 'Reset your password', react: ResetPasswordEmail({ url }) }, env.RESEND_API_KEY, env.EMAIL_FROM),
    },
    emailVerification: {
      sendVerificationEmail: async ({ user, url }) =>
        sendEmail({ to: user.email, subject: 'Verify your email', react: VerifyEmail({ url }) }, env.RESEND_API_KEY, env.EMAIL_FROM),
    },
  })
}
```

```ts
// src/lib/auth-client.ts
import { createAuthClient } from 'better-auth/react'
export const authClient = createAuthClient()
export const { signIn, signOut, signUp, useSession } = authClient
```

Read session on the server: `await auth.api.getSession({ headers: request.headers })` (build `auth` per request via `createAuth`). If immediate session revocation matters, keep the canonical session check in Postgres or route revocation through a Durable Object; KV is eventually consistent. Re-run `bunx @better-auth/cli generate` + a new Drizzle migration after every Better Auth upgrade.

### Email (Resend + React Email)

```ts
// src/lib/email.ts
import { Resend } from 'resend'
import type { ReactElement } from 'react'

export async function sendEmail(opts: { to: string; subject: string; react: ReactElement }, apiKey: string, from: string) {
  const { error } = await new Resend(apiKey).emails.send({ from, ...opts })
  if (error) throw new Error(`email send failed: ${error.message}`)
}
```

```tsx
// src/emails/VerifyEmail.tsx
import { Button, Html, Text } from '@react-email/components'

export const VerifyEmail = ({ url }: { url: string }) => (
  <Html>
    <Text>Confirm your email to finish signing up.</Text>
    <Button href={url}>Verify email</Button>
  </Html>
)
```

Bindings: `RESEND_API_KEY`, `EMAIL_FROM` (verified Resend sender), read from `c.env`.

### Logging (pino)

```ts
// src/lib/logger.ts
import pino from 'pino'

export const logger = pino({ level: process.env.LOG_LEVEL ?? 'info' })
```

Mount on Hono so every request has `c.var.logger`:

```ts
import { pinoLogger } from 'hono-pino'
app.use('*', pinoLogger({ pino: logger }))
```

Use `c.var.logger.info({ userId }, 'posted')` in handlers. On Workers, view logs with `wrangler tail` or the observability dashboard. No `console.log` in committed code. (`pino-pretty` is a dev-only transport; don't ship it to Workers.)

### Error monitoring (Sentry)

Server: wrap the Worker fetch handler with `@sentry/cloudflare`. Capture in the Hono error handler:

```ts
import * as Sentry from '@sentry/cloudflare'

app.onError((err, c) => {
  Sentry.captureException(err)
  c.var.logger?.error({ err }, 'unhandled')
  return c.json({ error: 'internal' }, 500)
})
```

Init reads `SENTRY_DSN` from the Worker env, not an import-order side effect. React side: follow `@sentry/tanstackstart-react` router instrumentation.

### Security middleware

CORS, secure headers, and a rate limit on `/auth/*` are non-negotiable.

```ts
// src/server/hono.ts
import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { secureHeaders } from 'hono/secure-headers'

export const app = new Hono().basePath('/api')

// KV-backed so counts survive across isolates (approximate — KV is eventually consistent)
async function rateLimit(kv: KVNamespace, keyPrefix: string, limit = 20, windowSec = 900) {
  const windowId = Math.floor(Date.now() / 1000 / windowSec)
  const key = `${keyPrefix}:${windowId}`
  const n = Number((await kv.get(key)) ?? 0) + 1
  await kv.put(key, String(n), { expirationTtl: windowSec * 2 })
  return n <= limit
}

app.use('*', secureHeaders())
app.use('*', (c, next) =>
  cors({ origin: c.env.PUBLIC_ORIGIN, credentials: true })(c, next))

app.use('/auth/*', async (c, next) => {
  const ip = c.req.header('cf-connecting-ip') ?? 'anon'
  const kv = c.env.KV
  if (!(await rateLimit(kv, `rate-limit:${ip}:${c.req.path}`, 20, 900))) {
    return c.text('Too many requests', 429)
  }
  await next()
})

// Build request-scoped db + auth from bindings, then delegate to the handler
app.on(['GET', 'POST'], '/auth/*', async (c) => {
  const { createDb } = await import('~/db')
  const { createAuth } = await import('~/lib/auth')
  const db = createDb(c.env.HYPERDRIVE.connectionString)
  const auth = createAuth(db, c.env)
  return auth.handler(c.req.raw)
})
```

`cf-connecting-ip` is the real client IP on Cloudflare — never `x-forwarded-for`. The KV rate limiter uses a fixed window based on time intervals, which is approximate due to eventual consistency. KV is acceptable for approximate throttles; for hard per-key limits use a Durable Object or Cloudflare's rate limiting binding.

### TanStack Form + Zod

One schema, both sides.

```ts
// src/schemas/post.ts
import { z } from 'zod'
export const postInput = z.object({ title: z.string().min(1).max(200), body: z.string().min(1) })
export type PostInput = z.infer<typeof postInput>
```

```tsx
const form = useForm({
  defaultValues: { title: '', body: '' },
  validators: { onSubmit: postInput },
  onSubmit: async ({ value }) => { /* server fn or RPC */ },
})
```

Server: parse with the same schema before the DB.

## Configuration

### Vite + Tailwind v4

```ts
// vite.config.ts
import { defineConfig } from 'vite'
import { cloudflare } from '@cloudflare/vite-plugin'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import viteReact from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  // cloudflare() builds the Worker; assign it the framework's `ssr` environment
  plugins: [
    cloudflare({ viteEnvironment: { name: 'ssr' } }),
    tanstackStart(),
    viteReact(),
    tailwindcss(),
  ],
})
```

```css
/* src/styles/app.css */
@import "tailwindcss";

@theme {
  --color-brand: oklch(0.7 0.18 250);
  --font-display: "Inter", sans-serif;
}
```

No `tailwind.config.js` — tokens live in `@theme`. shadcn/ui must use its v4 mode.

### Biome

```json
{
  "$schema": "https://biomejs.dev/schemas/2.0.0/schema.json",
  "files": { "ignoreUnknown": true, "includes": ["**", "!**/drizzle/**", "!**/.output/**", "!**/node_modules/**"] },
  "formatter": { "indentStyle": "space", "indentWidth": 2, "lineWidth": 100 },
  "linter": { "enabled": true, "rules": { "recommended": true } },
  "javascript": { "formatter": { "quoteStyle": "single", "semicolons": "asNeeded" } }
}
```

`bunx biome check --write` locally, `bunx biome ci` in CI.

### TypeScript

`tsconfig.json`: `strict`, `moduleResolution: "bundler"`, `verbatimModuleSyntax: true`, alias `"~/*": ["./src/*"]`, and `"types": ["@cloudflare/workers-types"]` so `KVNamespace` / `Hyperdrive` binding types resolve.

### Environment variables

| Scope | Convention | Access |
|---|---|---|
| Public (client-safe) | `VITE_` prefix | `import.meta.env.VITE_FOO` |
| Server secrets | Worker binding | `c.env.FOO` (Hono) / request context (server fn) |

Secrets (`BETTER_AUTH_SECRET`, `RESEND_API_KEY`, `SENTRY_DSN`) are Worker secrets — `wrangler secret put NAME`, never in `wrangler.toml` or the client bundle. `process.env` is empty on Workers unless `nodejs_compat` is on; prefer bindings. The build strips non-`VITE_` variables from client bundles automatically.

The `Env` type (binding + secret names) is generated by `bunx wrangler types` (add a `cf-typegen` script) — re-run it after editing `wrangler.toml`.

### lefthook

```yaml
# lefthook.yml
pre-commit:
  parallel: true
  commands:
    biome:
      glob: '*.{ts,tsx,js,jsx,json,jsonc}'
      run: bunx biome check --write --no-errors-on-unmatched {staged_files}
      stage_fixed: true
```

`bunx lefthook install` once per clone.

### GitHub Actions

```yaml
# .github/workflows/ci.yml
name: CI
on: { pull_request: {}, push: { branches: [main] } }
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
      - run: bun install --frozen-lockfile
      - run: bunx biome ci
      - run: bunx tsc --noEmit
      - run: bun test
  deploy:
    needs: check
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
      - run: bun install --frozen-lockfile
      - run: bun run build          # produce the Worker output before deploy
      - run: bunx wrangler deploy
        env: { CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }} }
```

Run `bunx drizzle-kit migrate` (against `DATABASE_URL`, direct to Postgres) as a pre-deploy step.

### For AI tooling

Conventions that help AI models generate correct, server-safe code.

**File naming** (TanStack official):
- `*.functions.ts` — `createServerFn` wrappers, safe to import anywhere
- `*.server.ts` — server-only code (DB queries, secret reads), only imported inside server function handlers
- `*.ts` (no suffix) — client-safe code (types, schemas, constants)

**Import boundaries**:
- `@tanstack/react-start/server-only` — marks a module as server-only; importing it in client code triggers a build error

**Co-location**:
- Place server functions next to the component that uses them
- Don't group by layer (controllers/, services/) — group by feature

**Rules for AI**:
- Use `createServerFn`, never `"use server"` directives (Next.js pattern)
- Use TanStack Router, not React Router
- Read secrets from Worker bindings (`c.env`), public values from `import.meta.env.VITE_X`
- Build DB client and Better Auth per request from bindings — never module-level singletons
- Loaders handle data fetching; never use `getServerSideProps` or `getStaticProps`
- TanStack's built-in CSRF middleware (`createCsrfMiddleware`) protects server functions by default; add it explicitly if you define `src/start.ts`

## Testing

```ts
import { describe, expect, test } from 'bun:test'
test('adds', () => { expect(1 + 1).toBe(2) })
```

`bun test`, `--watch`, `--coverage`. DB tests: real Postgres in Docker on a test port, reset between suites, never mock the ORM. `bun test` runs under Bun locally — keep runtime code Web-standard so it behaves the same on Workers. For Workers-only behavior (bindings, `ctx.waitUntil`, Durable Objects, Hyperdrive local bindings), allow the official Cloudflare Vitest pool in a separate integration-test setup.

## Deployment: Cloudflare Workers

`wrangler deploy` builds from source and ships to Workers. Self-hosted Postgres is reached through **Hyperdrive** (connection pooler + query cache) — Workers can't reuse long-lived TCP across requests, and Hyperdrive pools them at the edge.

```toml
# wrangler.toml
name = "my-app"
main = "@tanstack/react-start/server-entry"   # @cloudflare/vite-plugin resolves the built Worker
compatibility_date = "2025-01-01"
compatibility_flags = ["nodejs_compat"]

[[hyperdrive]]
binding = "HYPERDRIVE"
id = "<id from `wrangler hyperdrive create`>"

[[kv_namespaces]]
binding = "KV"
id = "<id from `wrangler kv namespace create`>"

[vars]
PUBLIC_ORIGIN = "https://my-app.example.com"
# Secrets (never here): wrangler secret put BETTER_AUTH_SECRET / RESEND_API_KEY / SENTRY_DSN
```

Setup:

1. Provision Hyperdrive over your Postgres: `bunx wrangler hyperdrive create my-app-db --connection-string="..."`; put the id in `wrangler.toml`.
2. Add `@cloudflare/vite-plugin` to `vite.config.ts` (see *Vite + Tailwind v4*); run `bunx wrangler types` for the `Env` type.
3. Secrets: `wrangler secret put BETTER_AUTH_SECRET` (`openssl rand -base64 32`), `RESEND_API_KEY`, `SENTRY_DSN`.
4. `bunx drizzle-kit migrate` against `DATABASE_URL` (direct to Postgres, not Hyperdrive).
5. `bunx wrangler deploy` (or push to `main` — see CI). Add a custom domain in the Cloudflare dashboard.

## Gotchas

- **Bindings are request-time only** — build the DB client and Better Auth inside the handler from `c.env`, never at module top level. Module-level `postgres(...)` calls have no binding and break on Workers.
- **`nodejs_compat` is required** for `postgres.js` (it needs the Node `net` polyfill). Set `compatibility_flags = ["nodejs_compat"]`.
- **Hyperdrive vs migrations**: runtime reads the connection string from `env.HYPERDRIVE.connectionString`; `drizzle-kit` migrations connect to `DATABASE_URL` directly (Hyperdrive isn't a migration endpoint).
- **Smart Placement**: consider it for DB-heavy routes with multiple backend round trips; avoid it for static/asset-heavy Workers unless you split backend logic into a separate Worker.
- **`process.env` is empty on Workers** unless `nodejs_compat` — read config from `c.env` / bindings.
- **No Lambda-style cold start**: V8 isolates start in ms. But there's **no persistent state between requests** — don't cache a DB pool at module scope expecting reuse.
- **CPU time limit**: 30s default on paid (configurable up to 5 min); wall-clock for I/O is not counted. Free tier is tightly limited.
- **Rate-limit key**: on Cloudflare use `cf-connecting-ip`, never `x-forwarded-for`. In-memory limits don't span isolates; KV is only approximate. For exact per-key counts use a Durable Object or Cloudflare's rate limiting binding.
- **KV is eventually consistent** and read-cached (~60s): useful for session/cache acceleration and approximate throttles, wrong for immediate global revocation, read-after-write, or atomic counters — use Postgres or a Durable Object there.
- **Tailwind v4** has no JS config — tokens in CSS `@theme`. Use v4-compatible shadcn only.
- **Postgres driver**: default to `postgres-js` with `drizzle-orm/postgres-js`; allow `pg` only when a dependency or official Cloudflare integration makes it the safer path.
- **Hono mount**: catch-all must be `src/routes/api/$.ts`. Don't share paths with server functions — silent 404s.
- **Better Auth tables** are generated; never hand-edit `src/db/auth-schema.ts`. Regenerate + new migration after upgrades.
- **Better Auth on Workers** hashes via Web Crypto (scrypt) — no `bcrypt`/`argon2`, which don't run on Workers anyway.
- **Sentry on Workers**: use `@sentry/cloudflare` (handler wrapper + `captureException`), not `@sentry/bun`. Client side is `@sentry/tanstackstart-react`.
- **Resend sender**: `EMAIL_FROM` must be on a verified domain — Better Auth flows fail silently otherwise; check the Resend dashboard.
- **Biome doesn't sort Tailwind classes**. Accept the order or add `prettier-plugin-tailwindcss` for that one concern.
- **Bun lockfile** is `bun.lock` (text). Commit it.
- **`console.log` is banned** in committed code — use `c.var.logger`. Inspect Workers logs with `wrangler tail`.

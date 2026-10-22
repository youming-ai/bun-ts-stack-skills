---
name: tanstack
description: All-in-Cloudflare TypeScript conventions for apps on Bun + TanStack Start, deployed to Cloudflare Workers. Covers scaffolding, layout, integrations, config, and deploy for the canonical stack of Bun (dev tooling), TanStack Start, Vite, Void (deploy), Drizzle ORM, Cloudflare D1, R2, KV, Queues, Workflows, Workers AI, Vectorize, Better Auth, Cloudflare Email Sending, Tailwind v4, shadcn/ui, TanStack Form, Zod, and Vitest. Use whenever the user is scaffolding, configuring, writing code for, or deploying a project mentioning ANY of these — including "set up a new project", "add auth", "send emails", "upload files", "rate limit", "CI pipeline", "Drizzle schema", "server function", "deploy to Cloudflare", "void deploy", "Workers", "D1", "R2", "my stack", or "this project" in a Bun + TanStack context. Trigger even when only a subset is mentioned, since it is the project's canonical stack and other choices should be checked against it.
---

# TanStack Start on Cloudflare

Conventions for full-stack TypeScript apps on Bun + TanStack Start, running entirely on Cloudflare. Source of truth for stack choices, layout, integrations, and deploy. Deviate only with explicit reason.

**Everything is a Cloudflare binding.** No external database, no external mail provider, no separate API server. One Worker, one `void deploy`.

## Stack

| Layer        | Choice                                          |
| ------------ | ----------------------------------------------- |
| Dev runtime  | Bun (package manager, scripts)                  |
| Prod runtime | Cloudflare Workers (V8 isolate)                 |
| Language     | TypeScript (strict)                             |
| Framework    | TanStack Start (React 19 + TanStack Router)     |
| Build        | Vite + `voidPlugin()` (wraps the Cloudflare Vite plugin) |
| API          | Server functions + route `server.handlers`      |
| ORM          | Drizzle (migrations via `void db`)              |
| Database     | Cloudflare D1 (SQLite)                          |
| KV           | Cloudflare KV (session cache, auth rate limits) |
| Auth         | Better Auth                                     |
| Email        | Cloudflare Email Sending (`send_email` binding) |
| CSS          | Tailwind v4 (`@tailwindcss/vite`)               |
| UI           | shadcn/ui (Radix + Tailwind) + lucide-react     |
| Forms        | TanStack Form                                   |
| Validation   | Zod                                             |
| Logs         | Workers Observability (`console` + Workers Logs, `void project logs`)|
| Test         | Vitest + `@cloudflare/vitest-pool-workers`      |
| Deploy       | `bunx void deploy` (Void CLI)                   |

### Non-negotiables

- Bun is the dev runtime: package manager and script runner. Never `npm` / `pnpm` / `yarn` / `node`. (Tests run in workerd via Vitest, not in Bun.)
- Production runs on **Cloudflare Workers** — a V8 isolate, not Node. Runtime code uses Web-standard APIs (`fetch`, Web Crypto, Streams).
- No Bun-specific APIs (`Bun.password`, `bun:sqlite`, `Bun.s3`) in runtime code — it never executes under Bun. Dev, test, and prod all run on workerd.
- **Bindings are request-time.** Build the DB client and Better Auth inside the handler, never at module top level. Isolates can be reused across a binding or secret change, so a client built at module scope keeps the old value; per-request construction always sees the current one.
- TypeScript `strict: true` everywhere.
- Do not install: `dotenv`, `ts-node`, `tsx`, `nodemon`, `jest`, `bcrypt`, `argon2`, `node-fetch`, `nodemailer`, `winston`, `bunyan`, `pino`, `hono`, `express`.
- **Version policy**: TanStack Start tracks one major behind current when a previous major exists. Today only `1.x` has ever shipped, so pin `"@tanstack/react-start": "^1.168"` in `package.json` and bump deliberately. Pin `void` too (`^1.2`) — the CLI must match the installed package version or Cloudflare deploys refuse to run.
- Vitest is the test runner, always through `@cloudflare/vitest-pool-workers` so tests get real bindings. Not `bun test`, not `jest`.

### Deliberately unconfigured

No formatter/linter, no git hooks, no CI pipeline — deferred, not rejected. Nothing in this skill depends on them, so adding them later is additive. When that day comes: Biome for lint/format, lefthook for hooks, GitHub Actions from `bunx void init --github`, plus `bunx void prepare` + `bunx tsc --noEmit` + `bunx vitest run` before deploy.

### Add only when the need is real

Everything below is **not** in the default stack. Add one when the listed condition is actually hit, not in anticipation.

| Need                                                       | Add                                                    |
| ---------------------------------------------------------- | ------------------------------------------------------ |
| Relational workload D1 can't hold (>10 GB, Postgres-only SQL) | PostgreSQL via Hyperdrive + `postgres` driver + `drizzle-orm/postgres-js` |
| Semantic search, RAG, similarity over text                  | Workers AI (embeddings) + **Vectorize** binding (native vector store on Workers) |
| Append-only time-series analytics (signups, feature-flag hits, email opens) | **Workers Analytics Engine** binding (SQL-queryable, no extra infra) |
| Long-running or multi-step background jobs (cleanup, digests, reports) | Cloudflare **Queues** (consumers) / **Workflows** (durable, retryable, step-based) |
| Scheduled jobs (cleanup, digests, reports)                 | A handler in `crons/` (Void provisions the Cron Trigger) |
| Realtime / WebSocket app (presence, collaboration)         | Durable Object with **WebSocket Hibernation**           |
| Strong consistency, atomic counters, single-writer state   | Durable Object                                         |
| Headless Chrome (PDF/screenshot, scraping)                 | Workers **Browser Rendering** binding (open beta)       |
| Long-lived non-V8 task (ffmpeg, heavy CPU, GPU)            | Cloudflare **Containers** (open beta)                   |
| User uploads / large media                                 | R2 binding — serve via a route handler, no S3 SDK       |
| AI features (chat, classification, embeddings)              | Workers AI binding — no external API key               |
| Rate limits on non-auth routes                             | Cloudflare `ratelimits` binding                        |
| Bot protection on signup / public forms                    | Cloudflare Turnstile — free, no CAPTCHA friction       |
| Admin panel auth / internal tooling                        | Cloudflare Access (Zero Trust) — no custom auth code    |
| Centralized secret governance across Workers               | **Cloudflare Secrets Store** binding (vs per-Worker `void secret put`) |
| Private network path to on-prem DB                         | Workers **VPC** binding (open beta)                     |
| Marketing email, templates, campaign analytics             | Resend + React Email (transactional stays on the binding) |
| Error alerting / release tracking beyond Workers Logs      | `@sentry/cloudflare` + `@sentry/tanstackstart-react`   |
| Standalone API with many middleware layers or OpenAPI      | Hono, mounted at `src/routes/api/$.ts`                 |
| Second language                                            | i18n lib of choice — do not hand-roll                  |

## Architecture

```mermaid
flowchart LR
  subgraph Build
    R[Routes SSG] -->|prerender| H[flat HTML]
  end
  H -->|no Worker run| CDN[Cloudflare CDN] --> Browser

  subgraph Request
    SSR[Routes SSR / default] --> W[Cloudflare Worker]
    SFN[createServerFn stub<br/>co-located, same file] -->|typed POST| W
    W -->|React server render| Browser2[Browser]
    W --> D1[(D1)]
    W --> KV[(KV)]
    W --> MAIL[(send_email)]
    W --> Q[(Queues / Workflows)]
    W --> AI[(Workers AI / Vectorize)]
    D1 -. Drizzle / Better Auth .- W
  end
```

- CRUD → **server functions** co-located with components.
- Webhooks, files, anything non-React → **route `server.handlers`** (`src/routes/api/*.ts`).
- **Better Auth** mounts as a route handler and uses Drizzle over D1.
- One **Zod schema** per concept in `src/schemas/`, shared by server fn / Form / validation.
- Secrets come from **Worker bindings**, never `process.env`. Public values use the `VITE_` prefix.

### Rendering strategy

_Rendering, execution-model, secrets, and deploy flows below are adapted from Lovable's [Building apps using TanStack Start](https://lovable.dev/blog/building-apps-using-tanstack-start)._

| Route type                              | Mode         | How                                                                 |
| --------------------------------------- | ------------ | ------------------------------------------------------------------- |
| Data-independent (landing, blog, about) | Static (SSG) | `tanstackStart({ prerender: { enabled: true } })` in `vite.config.ts` |
| Per-request data (dashboard, account)   | Server (SSR) | default                                                             |
| Purely client-rendered                  | CSR          | `ssr: false` route option in `createFileRoute(...)({ ... })`        |

Prerendered routes serve flat HTML from the CDN with no Worker invocation — use them for everything that doesn't read per-user data.

Why not CSR by default: a client-rendered page ships an empty `<div id="root">` shell, so content needs two round trips (JS, then data). Crawlers render it late or not at all, and social previewers (Slack, LinkedIn, X) only read the initial HTML's meta tags. With SSR the Worker runs loaders and streams finished HTML on the first request:

```mermaid
sequenceDiagram
  participant B as Browser
  participant W as Cloudflare Worker
  participant D as D1
  B->>W: GET /dashboard
  W->>W: TanStack Start SSR render
  W->>D: createServerFn → query
  D-->>W: rows
  W-->>B: HTML with content
```

### Execution model

Code is **isomorphic by default**: route modules, loaders, and components land in both the server and client bundles. Server-only or client-only code is marked with an explicit boundary.

`createServerFn` is that boundary. The Start Vite plugin transforms it at build time: the server bundle keeps the handler body; the client bundle replaces it with a typed `fetch` stub that POSTs to the server-fn endpoint. Write it like a normal function, import it anywhere, keep it next to the component — one file, one deploy, end-to-end types from call site to handler. No separate API service.

## Project structure

```
src/
├── routes/
│   ├── __root.tsx
│   ├── index.tsx
│   └── api/auth/$.ts             # Better Auth handler
├── db/index.ts                   # Drizzle client (from D1 binding)
├── lib/
│   ├── auth.ts, auth-client.ts
│   └── email.ts                  # void/email wrapper (throws on failure)
├── schemas/                      # shared Zod schemas
├── components/{ui,forms}/
├── styles/app.css                # @import "tailwindcss"
├── start.ts                      # global request middleware (security headers)
├── server.ts                     # optional custom Worker entry (Durable Object / Workflow exports)
└── router.tsx
db/                               # Void convention, project root (not src/)
├── schema.ts                     # business tables + `export * from './auth-schema'`
├── auth-schema.ts                # Better Auth (CLI-generated, do not edit)
└── migrations/                   # generated by `void db generate`
queues/email.ts                   # queue consumer (Void convention)
.env                              # local values only, gitignored (no .dev.vars)
void.config.ts, void.lock.json    # commit both; .void-wrangler.jsonc is generated, gitignored
vite.config.ts, vitest.config.ts
```

## Setup

### Scaffold

```bash
# Official TanStack CLI — pick Bun as package manager when prompted.
# `bun create tsrouter-app@latest my-app` still works as a legacy alias.
bunx @tanstack/cli@latest create my-app && cd my-app
```

### Install

```bash
# Runtime
bun add drizzle-orm better-auth zod @tanstack/react-form tailwindcss @tailwindcss/vite

# Dev
bun add -d void @vitejs/plugin-react                  # void brings the Cloudflare Vite plugin, Drizzle Kit, and the deploy CLI
bun add -d vitest@4 @cloudflare/vitest-pool-workers   # pool peer is vitest ^4.1 — not 5

# UI
bunx shadcn@latest init
```

### Provision Cloudflare resources

Nothing to run by hand. Void infers bindings from code (`env.DB` → D1, `env.KV` → KV, `env.STORAGE` → R2, `env.AI` → Workers AI, a file in `queues/` → a Queue), creates missing resources on the first `void deploy`, and records their IDs in `void.lock.json`. The email domain is set up from `email.from` in `void.config.ts` (Void asks before changing DNS).

```bash
bunx void init      # pick Cloudflare as the target; writes void.config.ts
```

Run the first deploy from one machine and commit `void.lock.json` before deploying from anywhere else — a parallel first deploy provisions duplicates.

### Auth schema & migrations

```bash
# After writing src/lib/auth.ts
bunx @better-auth/cli generate --output db/auth-schema.ts

# Migrations: Void reads db/schema.ts and writes SQL + Drizzle metadata to db/migrations/.
bunx void db generate
bunx void db migrate          # apply to the local D1
# Remote is applied by `void deploy` (after a D1 Time Travel restore point).
```

### Regenerate Env types

```bash
# Re-run after changing bindings or void.config.ts; writes types under .void/.
bunx void prepare
```

## Integration patterns

### Drizzle over D1

D1 is a binding, not a connection string — no pool, no driver, no `DATABASE_URL`. Read the binding inside the request.

```ts
// src/db/index.ts
import { drizzle } from 'drizzle-orm/d1'
import { env } from 'cloudflare:workers'
import * as schema from '@schema' // Void alias for db/schema.ts (re-exports auth-schema)

// Call inside a handler. Bindings are request-scoped — never at module top level.
export const getDb = () => drizzle(env.DB, { schema })
export type DB = ReturnType<typeof getDb>
```

```ts
// db/schema.ts — SQLite tables, not pg
import { integer, sqliteTable, text } from 'drizzle-orm/sqlite-core'

export const posts = sqliteTable('posts', {
  id: text('id').primaryKey(),
  title: text('title').notNull(),
  body: text('body').notNull(),
  createdAt: integer('created_at', { mode: 'timestamp_ms' }).notNull(),
})

export * from './auth-schema'
```

Workflow: `void db generate` writes SQL into `db/migrations/`; `void db migrate` applies it locally; `void deploy` applies it remotely. No `drizzle.config.ts`, no `drizzle-kit` — Void owns the schema path and migration history, and deploy stops if the schema has changes without a migration.

#### If you outgrow D1 and switch to Postgres

Postgres on Workers **must** go through Hyperdrive — an isolate can't hold a long-lived TCP connection across requests, and Hyperdrive pools them at the edge. Void wires this up:

1. Set `database: 'pg'` in `void.config.ts`; put `DATABASE_URL` in `.env` locally and in the shell that runs `void deploy` (Void creates Hyperdrive from it and runs migrations against it directly — it is never written to config).
2. Schema moves to `pg-core` (or `void/schema-pg`); Better Auth adapter goes `provider: 'sqlite'` → `'pg'`.
3. Query through `db` from `void/db` — it connects via Hyperdrive in production and directly in dev, so `getDb()` goes away.
4. Keep `nodejs_compat`.

For routes with several DB round trips, consider Smart Placement so the Worker runs closer to the database — but not on asset-heavy Workers.

### Better Auth

Better Auth needs the DB, so it is request-scoped too.

```ts
// src/lib/auth.ts
import { betterAuth } from 'better-auth'
import { drizzleAdapter } from 'better-auth/adapters/drizzle'
import { tanstackStartCookies } from 'better-auth/tanstack-start'
import { env } from 'cloudflare:workers'
import { getDb } from '~/db'
import { sendEmail } from '~/lib/email'

export function getAuth() {
  return betterAuth({
    database: drizzleAdapter(getDb(), { provider: 'sqlite' }),
    // KV keeps session reads off D1's single-region write primary.
    secondaryStorage: {
      get: (key) => env.KV.get(key),
      set: (key, value, ttl) => env.KV.put(key, value, ttl ? { expirationTtl: ttl } : undefined),
      delete: (key) => env.KV.delete(key),
    },
    // Built-in limiter — do not hand-roll one
    rateLimit: {
      enabled: true,
      storage: 'secondary-storage',
      customRules: { '/sign-in/email': { window: 60, max: 5 } },
    },
    secret: env.BETTER_AUTH_SECRET,
    baseURL: env.PUBLIC_ORIGIN,
    emailAndPassword: {
      enabled: true,
      requireEmailVerification: true,
      sendResetPassword: ({ user, url }) =>
        sendEmail(user.email, 'Reset your password', `<a href="${url}">Reset your password</a>`),
    },
    emailVerification: {
      sendVerificationEmail: ({ user, url }) =>
        sendEmail(user.email, 'Verify your email', `<a href="${url}">Verify your email</a>`),
    },
    socialProviders: {
      google: { clientId: env.GOOGLE_CLIENT_ID, clientSecret: env.GOOGLE_CLIENT_SECRET },
      github: { clientId: env.GITHUB_CLIENT_ID, clientSecret: env.GITHUB_CLIENT_SECRET },
    },
    // tanstackStartCookies must be the LAST plugin in the array.
    plugins: [tanstackStartCookies()],
  })
}
```

```ts
// src/routes/api/auth/$.ts
import { createFileRoute } from '@tanstack/react-router'
import { getAuth } from '~/lib/auth'

const handler = ({ request }: { request: Request }) => getAuth().handler(request)

export const Route = createFileRoute('/api/auth/$')({
  server: { handlers: { GET: handler, POST: handler } },
})
```

```ts
// src/lib/auth-client.ts
import { createAuthClient } from 'better-auth/react'
export const authClient = createAuthClient()
export const { signIn, signOut, signUp, useSession } = authClient
```

Server-side session, inside a `createServerFn` handler or route `beforeLoad`:

```ts
// inside a server fn / beforeLoad
import { getRequestHeaders } from '@tanstack/react-start/server'
const session = await getAuth().api.getSession({ headers: getRequestHeaders() })
```

Providers beyond the built-ins:

- **Phone OTP** → `phoneNumber` plugin from `better-auth/plugins`; supply `sendOTP` (SMS provider is yours).
- **WeChat** → `genericOAuth` plugin from `better-auth/plugins`; WeChat is not a built-in provider.

Re-run `bunx @better-auth/cli generate --output db/auth-schema.ts` + `bunx void db generate` after every Better Auth or plugin change — plugins add tables. Void-managed auth (`void/auth`) is not supported for TanStack Start yet; Better Auth stays wired by hand as above.

### Email (Cloudflare Email Sending)

No API key — `sendEmail` from `void/email` sends through the Cloudflare `send_email` binding in production and into a local inbox in dev. Sender comes from `email.from` in `void.config.ts`.

```ts
// src/lib/email.ts
import { sendEmail as voidSend } from 'void/email'

export async function sendEmail(to: string, subject: string, html: string) {
  const result = await voidSend({
    to,
    subject,
    html,
    text: html.replace(/<[^>]+>/g, ' ').trim(), // clients that only show plain text
  })
  // void/email returns a result instead of throwing — surface failures so
  // Better Auth's verify/reset flows don't silently "succeed".
  if (!result.ok) throw new Error(`sendEmail failed: ${JSON.stringify(result)}`)
}
```

`void deploy` checks the `email.from` domain and offers to set it up (it must be a zone on your account). Transactional only — marketing sends belong on a marketing platform.

### R2 (not in the base stack)

Add it when there are actual uploads. Reading `env.STORAGE` is enough — Void infers the R2 binding and creates the bucket on deploy.

It's a binding like the rest — serve through a route handler, never add an S3 SDK:

```ts
// src/routes/api/files/$key.ts
import { createFileRoute } from '@tanstack/react-router'
import { env } from 'cloudflare:workers'

export const Route = createFileRoute('/api/files/$key')({
  server: {
    handlers: {
      GET: async ({ params }) => {
        const obj = await env.STORAGE.get(params.key)
        if (!obj) return new Response('Not found', { status: 404 })
        return new Response(obj.body, {
          headers: { 'content-type': obj.httpMetadata?.contentType ?? 'application/octet-stream' },
        })
      },
    },
  },
})
```

Authorize writes **before** calling `env.STORAGE.put()` — the route handler is the trust boundary, not R2. For large or direct-from-browser uploads, put the bucket behind a custom domain or issue presigned URLs instead of streaming through the Worker.

```ts
// src/routes/api/files/upload.ts — authorized PUT
import { createFileRoute } from '@tanstack/react-router'
import { env } from 'cloudflare:workers'
import { getAuth } from '~/lib/auth'
import { getRequestHeaders } from '@tanstack/react-start/server'

export const Route = createFileRoute('/api/files/upload')({
  server: {
    handlers: {
      PUT: async ({ request }) => {
        const session = await getAuth().api.getSession({ headers: getRequestHeaders() })
        if (!session) return new Response('Unauthorized', { status: 401 })

        const key = `${session.user.id}/${crypto.randomUUID()}`
        await env.STORAGE.put(key, request.body, {
          httpMetadata: { contentType: request.headers.get('content-type') ?? 'application/octet-stream' },
        })
        return Response.json({ key })
      },
    },
  },
})
```

### Queues & Workflows (background work)

Queues for at-least-once consumers; Workflows for durable, step-based, retryable orchestration.

A file in `queues/` is a consumer; its path is the queue name. Void provisions the queue and wires the handler — no Worker config, no custom entry.

```ts
// queues/email.ts
import { defineQueue } from 'void'
import { sendEmail } from '~/lib/email'

export type EmailOutbound = { to: string; subject: string; html: string }

export default defineQueue<EmailOutbound>(async (batch) => {
  for (const m of batch.messages) {
    try { await sendEmail(m.body.to, m.body.subject, m.body.html); m.ack() }
    catch { m.retry({ delaySeconds: 60 }) }
  }
})
```

```ts
// producer, inside a server fn — typed from the consumer's generic
import { queues } from 'void/queues'
await queues.email.send({ to, subject, html })
```

Cron jobs follow the same pattern in `crons/`. Durable Object and Workflow classes still need a custom entry: set `cloudflare: { main: './src/server.ts' }` in `void.config.ts`, `export default handler` from `@tanstack/react-start/server-entry` there, add the class as a named export, and bind it under `cloudflare.durable_objects` / `cloudflare.workflows`.

### Security headers

One global middleware, applied to every request including SSR and server functions.

```ts
// src/start.ts
import { createCsrfMiddleware, createMiddleware, createStart } from '@tanstack/react-start'
import { getResponseHeaders } from '@tanstack/react-start/server'

const securityHeaders = createMiddleware().server(async ({ next }) => {
  const result = await next()
  const headers = getResponseHeaders()
  headers.set('X-Content-Type-Options', 'nosniff')
  headers.set('X-Frame-Options', 'DENY')
  headers.set('Referrer-Policy', 'strict-origin-when-cross-origin')
  headers.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains')
  return result
})

export const startInstance = createStart(() => ({
  // createStart replaces the default requestMiddleware list, so the CSRF
  // middleware that Start auto-installs when no start.ts exists must be
  // re-added explicitly — otherwise server functions lose same-origin protection.
  requestMiddleware: [createCsrfMiddleware(), securityHeaders],
}))
```

**No CORS config.** The app and its API are same-origin. Add `cors` only if a different origin genuinely calls the API.

### TanStack Form + Zod

One schema, both sides.

```ts
// src/schemas/post.ts
import { z } from 'zod'
export const postInput = z.object({ title: z.string().min(1).max(200), body: z.string().min(1) })
export type PostInput = z.infer<typeof postInput>
```

```ts
// inside a component
const form = useForm({
  defaultValues: { title: '', body: '' },
  validators: { onSubmit: postInput },
  onSubmit: async ({ value }) => createPost({ data: value }),
})
```

Server functions parse with the same schema before touching the DB — client validation is UX, not a trust boundary.

## Configuration

### Vite + Tailwind v4

```ts
// vite.config.ts
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import tailwindcss from '@tailwindcss/vite'
import viteReact from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import { voidPlugin } from 'void'

export default defineConfig({
  plugins: [
    voidPlugin(), // must come before tanstackStart(); replaces @cloudflare/vite-plugin
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

### void.config.ts

There is no `wrangler.toml`. Authored settings live in `void.config.ts`; provisioned IDs live in `void.lock.json` (commit both). Void generates `.void-wrangler.jsonc` for Cloudflare tooling — gitignore it, never edit it.

```ts
// void.config.ts
import { defineConfig } from 'void/config'

export default defineConfig({
  worker: {
    compatibility_date: '2026-10-22', // bump periodically; older dates silently miss newer flag defaults
    compatibility_flags: ['nodejs_compat'],
    vars: { PUBLIC_ORIGIN: 'https://my-app.example.com' },
  },
  email: { from: 'My App <hello@example.com>' },
  cloudflare: {
    name: 'my-app',
    observability: { enabled: true },
  },
  // Secrets (never here): void secret put BETTER_AUTH_SECRET / GOOGLE_CLIENT_SECRET / ...
})
```

D1 (`env.DB`), KV (`env.KV`), R2 (`env.STORAGE`), Workers AI (`env.AI`), and queues are inferred — don't declare them. Bindings Void doesn't infer (`ratelimits`, Vectorize, Analytics Engine, service bindings, Durable Objects) go under `cloudflare` with the usual Wrangler field names; Void passes them through.

`nodejs_compat` is for Better Auth and React SSR internals, not a database driver.

### Environment variables

| Scope                | Convention     | Access                                        |
| -------------------- | -------------- | --------------------------------------------- |
| Public (client-safe) | `VITE_` prefix | `import.meta.env.VITE_FOO`                    |
| Server secrets       | Worker binding | `env.FOO` from `cloudflare:workers`           |

Secrets go in with `void secret put NAME` (bulk: `void secret sync <file>`); local values live in the root `.env`, which deploy never uploads. `.dev.vars` is not read. They are never part of the bundle — the runtime injects them as bindings at request time, so a rotation takes effect without a rebuild. With `nodejs_compat` and `compatibility_date` ≥ 2025-04-01, `process.env` is populated from vars and secrets too (useful for Node-style libraries), but app code reads `env` from `cloudflare:workers` — it's typed and includes non-text bindings. The build strips non-`VITE_` variables from client bundles, and ignores `VITE_*` from `.env` — pass production public values in the shell (`VITE_FOO=... void deploy`). `bunx void prepare` regenerates binding types.

```mermaid
sequenceDiagram
  participant Dev
  participant Build as Vite build
  participant W as Cloudflare Worker
  participant B as Browser
  Dev->>W: void secret put MY_SECRET_KEY
  Note over W: stored per Worker, outside the bundle
  Dev->>Build: void deploy
  Build->>Build: inline VITE_* into client bundle
  Build->>W: upload bundle (no secrets)
  B->>W: request
  Note over W: env.MY_SECRET_KEY available in createServerFn
  W-->>B: response
  Dev->>W: void secret put MY_SECRET_KEY (rotate)
  Note over W: next request sees new value, no rebuild
```

Because isolates can survive a binding change, never derive clients from a secret at module scope — they'd keep the old value. Build them per request (see Gotchas).

### TypeScript

`tsconfig.json`: `strict`, `moduleResolution: "bundler"`, `verbatimModuleSyntax: true`, alias `"~/*": ["./src/*"]`. Add `"types": ["void/env"]` for binding and Workers runtime types, and run `bunx void prepare` to generate `.void/` — do not hand-write `Env`.

### Observability

- **Workers Logs** are on when `cloudflare.observability.enabled` is `true` — `console.log` calls are captured automatically, no library.
- **Live tail**: `bunx void project logs` streams invocation logs (errors, `console.*`, invocation status).
- **Logpush**: for retention beyond Workers' own retention window, ship logs to R2 / S3 / a HTTPS destination via a Logpush job. Configure the job in the dashboard.
- **Invocation analytics**: Workers Observability dashboard surfaces CPU time, error rate, requests by colo.
- **Trace IDs**: generate one per request in `start.ts` (see Operational patterns) and log it with every line so a `void project logs` session can follow one request end-to-end.

## Deploy

Vite builds, Void deploys. One command from a clean checkout (first run opens a browser to log in to Cloudflare):

```bash
bunx void deploy
```

```mermaid
sequenceDiagram
  participant Dev
  participant VD as void deploy
  participant V as Vite build
  participant CF as Cloudflare
  Dev->>VD: void deploy
  VD->>CF: create missing resources (IDs → void.lock.json)
  VD->>V: build
  V->>V: client assets + SSR entry + prerender static routes
  VD->>CF: check secrets + migrations
  VD->>CF: D1 Time Travel restore point, apply db/migrations
  VD->>CF: upload Worker + assets (staged)
  VD->>CF: readiness check, then shift traffic
  CF-->>Dev: live URL (previous version restored if readiness fails)
```

Before deploying, run the checks CI would have run: `bunx void prepare`, `bunx tsc --noEmit`, and `bunx vitest run`.

After deploying: `void project status`, `void project logs`, `void project rollback`. Rollback does **not** reverse migrations — restore D1 with the `void db restore` command deploy printed (restore points last 7 days on Workers Free, 30 on Paid), or write a new migration.

## Testing

Vitest through `@cloudflare/vitest-pool-workers` — one runner for everything, and tests get real D1/KV bindings instead of mocks.

```ts
// vitest.config.ts
import { defineWorkersConfig } from '@cloudflare/vitest-pool-workers/config'

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: './.void-wrangler.jsonc' }, // generated by Void; run `void init` first
        miniflare: { compatibilityFlags: ['nodejs_compat'] },
      },
    },
  },
})
```

```ts
// db/posts.test.ts
import { env } from 'cloudflare:test'
import { expect, test } from 'vitest'
import { drizzle } from 'drizzle-orm/d1'
import { posts } from './schema'

test('inserts a post', async () => {
  const db = drizzle(env.DB, { schema: { posts } })
  await db.insert(posts).values({ id: '1', title: 't', body: 'b', createdAt: new Date() })
  expect(await db.select().from(posts)).toHaveLength(1)
})
```

`bunx vitest` (watch) / `bunx vitest run` (once) / `--coverage`. Apply migrations to the local D1 first (`void db migrate`). Never mock the ORM — the pool gives you a real local D1.

Add `@cloudflare/vitest-pool-workers` to `tsconfig.json` `types` so `cloudflare:test` resolves.

## Operational patterns

### Error handling & trace IDs

Wrap every server function / route handler in a single try/catch that logs a structured object with a per-request trace ID, then rethrows or returns a normalized error. The trace ID lets a `void project logs` session follow one request end-to-end across server fn → DB → email.

```ts
// src/lib/trace.ts
export function newTraceId() {
  return crypto.randomUUID()
}

// Log with context; pair with the trace ID set in start.ts middleware.
export function logCtx(traceId: string, event: string, fields: Record<string, unknown> = {}) {
  console.log({ traceId, event, ...fields })
}
```

```ts
// src/utils/posts.functions.ts
import { createServerFn } from '@tanstack/react-start'
import { z } from 'zod'
import { getDb } from '~/db'
import { posts } from '~/db/schema'
import { newTraceId, logCtx } from '~/lib/trace'

const createPostSchema = z.object({ title: z.string().min(1).max(200), body: z.string().min(1) })

export const createPost = createServerFn({ method: 'POST' })
  .validator(createPostSchema)
  .handler(async ({ data }) => {
    const traceId = newTraceId()
    try {
      logCtx(traceId, 'createPost.start', { title: data.title })
      const db = getDb()
      const [post] = await db.insert(posts).values({ id: crypto.randomUUID(), ...data, createdAt: new Date() }).returning()
      logCtx(traceId, 'createPost.ok', { id: post.id })
      return post
    } catch (e) {
      logCtx(traceId, 'createPost.error', { message: (e as Error).message })
      throw new Error('Failed to create post')
    }
  })
```

### ID generation

- **Primary keys are `text`, not auto-increment integers and not a `uuid` column type** (D1 has none). Generate ids in app code with `crypto.randomUUID()` (built into Web Crypto on Workers) or an ULID (`ulid` pkg) if you need time-sortable ids.
- **Timestamps are integer Unix-ms** with Drizzle `integer('...', { mode: 'timestamp_ms' })` (`'timestamp'` stores seconds). Drizzle maps them to `Date` in app code; do not mix `Date` objects and raw numbers across the wire — pick one and validate it with Zod at the server boundary.

### Migration discipline

- `db/migrations/` (SQL + `meta/`) is **generated**, never hand-edited. Change the schema in `db/schema.ts`, run `void db generate`, commit both.
- A PR that touches `db/schema.ts` **must** include the matching migration — `void deploy` refuses to deploy a schema with unmigrated changes.
- `void db migrate` applies locally; `void deploy` applies remotely. Never edit a migration after it has been deployed — write a new migration instead. `void db status` shows drift and pending migrations.

## Gotchas

- **Bindings are request-time** — call `getDb()` / `getAuth()` inside the handler. Isolates can be reused across a binding or secret change, so a client built at module scope keeps the old value; per-request construction always sees the current one.
- **D1 is SQLite**: no `jsonb`, no `uuid` type (ids are `text`), integer timestamps — `RETURNING` works (SQLite ≥ 3.35). Use `drizzle-orm/sqlite-core`, not `pg-core`.
- **D1 limits**: 10 GB per database (paid; 500 MB free), 2 MB max row/BLOB, 100 KB max statement, 30 s max query, 1000 queries per invocation. Writes hit a single-region primary; reads can scale out via D1 read replication (beta, paid). Cross-region read latency is why sessions sit in KV. Past these limits, switch to Hyperdrive + Postgres.
- **KV is eventually consistent** and read-cached (~60s): fine for session acceleration, wrong for immediate global revocation or atomic counters — use D1 or a Durable Object there.
- **Rate limiting**: Better Auth's built-in limiter covers auth routes. For others use the `ratelimits` binding (`period` is 10 or 60 seconds only, and counts are per-colo, not global).
- **Email**: `email.from` must be on a zone in your account, and sending to arbitrary recipients needs Workers Paid (Free only reaches verified destination addresses). `void/email` returns `{ ok: false }` instead of throwing — the wrapper must throw. Always send `text` alongside `html`.
- **No persistent state between requests**: V8 isolates start in ms but share nothing reliable. Never cache per-user state at module scope.
- **CPU time limit**: 30s default on paid (configurable up to 5 min); I/O wall-clock is not counted.
- **Better Auth on Workers** hashes via Web Crypto (scrypt) — `bcrypt` / `argon2` don't run on Workers anyway. Confirm the configured hash on Better Auth upgrades.
- **Bun lockfile** is `bun.lock` (text). Commit it.
- **Logging is `console`** with an object payload (`console.log({ traceId, event })`), captured by Workers Logs when `observability.enabled` is on. Inspect live with `void project logs`, or query in the Workers Observability dashboard. No log library — for retention beyond Workers' window, ship to R2 via Logpush.
- **`@cloudflare/vitest-pool-workers` pins its Vitest major** (peer `vitest ^4.1`). Bump the two together, or the pool refuses to load.
- **`compatibility_date` drift**: an old date silently disables newer compatibility-flag defaults. Bump `worker.compatibility_date` at least quarterly; the email/D1/ratelimits bindings need a recent date for the latest binding semantics.
- **Void plugin order**: `voidPlugin()` must come before `tanstackStart()` in `vite.config.ts`. Don't also add `@cloudflare/vite-plugin` — Void provides it.
- **Void state files**: commit `void.config.ts` and `void.lock.json`; gitignore `.void-wrangler.jsonc` and `.env`. Deleting the lock makes the next deploy provision new resources.
- **No named environments**: Void doesn't support Wrangler `[env.*]`. Staging is a separate Void project config.
- **Existing Worker with `wrangler.toml`**: convert it to `wrangler.jsonc` before the first `void deploy`; Void then migrates it into `void.config.ts` and keeps its bindings and secrets.

## Rules for AI

**File naming** (TanStack official):

- `*.functions.ts` — `createServerFn` wrappers, safe to import anywhere
- `*.server.ts` — server-only code (DB queries, secret reads)
- `*.ts` (no suffix) — client-safe code (types, schemas, constants)

`@tanstack/react-start/server-only` marks a module server-only; importing it from the client is a build error.

**Rules**:

- Use `createServerFn`, never `"use server"` directives (Next.js pattern).
- Use TanStack Router, not React Router. Loaders fetch data — never `getServerSideProps` / `getStaticProps`.
- Place server functions next to the component that uses them. Group by feature, not by layer.
- Reach for a binding before a package: D1 before an external DB, R2 before an S3 SDK, `send_email` before a mail SDK, `ratelimits` before a hand-rolled limiter, Vectorize before a hosted vector DB, Queues/Workflows before an external job runner.
- Generate ids in app code (`crypto.randomUUID()` / ULID); never rely on DB auto-increment.
- Never hand-edit `db/migrations/`; regenerate with `void db generate`.
- Provision, migrate, set secrets, and deploy with the `void` CLI — not `wrangler`. Don't write a `wrangler.toml`.
- Log structured objects with a trace ID — never stringly-typed logs.
- No `any`, no `as unknown as X`. If a type assertion feels necessary, widen the schema or the return type.
- Server function inputs and outputs must be serializable (Zod-validated in, JSON-safe out). `FormData` is allowed for POST server fns; `Response` is allowed as a return.

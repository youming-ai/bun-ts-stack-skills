---
name: tanstack
description: Full-stack TypeScript conventions for projects built on the Bun + TanStack Start ecosystem. Covers project scaffolding, directory structure, integration patterns, configuration, and deployment for the canonical stack of Bun runtime, TanStack Start, Vite, Hono, Drizzle ORM, PostgreSQL, Better Auth, Tailwind CSS v4, shadcn/ui, TanStack Form, Zod, Resend, pino, Sentry, lefthook, GitHub Actions, Biome, bun test, and Dokploy. Use this skill whenever the user is setting up, configuring, scaffolding, writing code, or deploying a project that mentions ANY of these technologies — including phrases like "set up a new project", "add auth", "send emails", "add logging", "rate limit", "CI pipeline", "Drizzle schema", "mount Hono", "deploy to Dokploy", "my stack", or "this project" in the context of Bun + TanStack work. Trigger this even when only a subset of these technologies is mentioned, since it is the project's canonical stack and other choices should be checked against it.
---

# TanStack Bun Stack

Project conventions for full-stack TypeScript apps built on Bun + TanStack Start. Treat this as the source of truth for stack choices, project layout, integration patterns, and deployment. Deviate only with explicit reason.

## Stack

| Layer       | Choice                                |
| ----------- | ------------------------------------- |
| Runtime     | Bun                                   |
| Language    | TypeScript (strict)                   |
| Framework   | TanStack Start                        |
| Build       | Vite                                  |
| API         | Hono                                  |
| ORM         | Drizzle + Drizzle Kit                 |
| Database    | PostgreSQL (driver: `postgres`)       |
| Auth        | Better Auth                           |
| CSS         | Tailwind v4 (`@tailwindcss/vite`)     |
| UI          | shadcn/ui + lucide-react              |
| Forms       | TanStack Form                         |
| Validation  | Zod                                   |
| Email       | Resend + React Email                  |
| Logging     | pino + `hono-pino`                    |
| Monitoring  | Sentry                                |
| Security    | `hono/cors`, `hono/secure-headers`, `hono-rate-limiter` |
| Lint/Format | Biome                                 |
| Git hooks   | lefthook                              |
| Test        | `bun test`                            |
| CI          | GitHub Actions                        |
| Deploy      | Dokploy on VPS (Docker)               |

### Non-negotiables

- Bun is the runtime, package manager, test runner, and script runner. Never reach for `npm` / `pnpm` / `yarn` / `node`.
- All code is TypeScript with `strict: true`.
- No Node-only dependencies. If a library doesn't work in Bun, find an alternative.
- Prefer Bun built-ins over third-party packages: `Bun.password`, `bun:sqlite`, `Bun.s3`, `Bun.file`, native `fetch`, `bun:test`, `bun --watch`.
- Do **not** install: `dotenv`, `ts-node`, `tsx`, `nodemon`, `jest`, `vitest`, `bcrypt`, `argon2`, `pg`, `better-sqlite3`, `node-fetch`, `eslint`, `prettier`, `nodemailer`, `husky`, `pre-commit`, `winston`, `bunyan`.

## Architecture

```
Browser
  │
  ▼
TanStack Start  (SSR + file-based routing)
  │
  ├── Server functions ──┐
  │                      ▼
  └── /api/*  ────►  Hono router  ──►  Better Auth handler
                        │
                        ▼
                     Drizzle  ──►  PostgreSQL
```

- Simple CRUD goes through **server functions** that Start exposes inline with components.
- Anything needing middleware, OpenAPI, RPC client, or external API surface goes through **Hono**, mounted as a catch-all at `/api/*`.
- **Better Auth** plugs into Hono as a request handler and into Drizzle as schema.
- A single **Zod schema** is shared across: Hono request validation, TanStack Form client validation, and Drizzle inserts. Define schemas once in `src/schemas/` and import everywhere.

## Project structure

```
src/
├── routes/
│   ├── __root.tsx
│   ├── index.tsx
│   └── api/
│       └── $.ts                  # catch-all → forwards to Hono
├── server/
│   ├── hono.ts                   # Hono app instance + sub-router mounting
│   ├── routers/                  # feature routers (posts.ts, users.ts, ...)
│   └── middleware/
├── db/
│   ├── index.ts                  # Drizzle client
│   ├── schema.ts                 # business tables
│   └── auth-schema.ts            # Better Auth tables (CLI-generated, do not edit)
├── lib/
│   ├── auth.ts                   # Better Auth server config
│   ├── auth-client.ts            # createAuthClient + hooks
│   ├── email.ts                  # Resend wrapper
│   ├── logger.ts                 # pino instance
│   └── sentry.ts                 # Sentry init (imported first thing)
├── emails/                       # React Email templates
├── schemas/                      # shared Zod schemas
├── components/
│   ├── ui/                       # shadcn/ui (generated)
│   └── forms/                    # TanStack Form wrappers
├── styles/
│   └── app.css                   # Tailwind v4 entry (@import "tailwindcss")
└── router.tsx
drizzle/                          # generated migrations
.github/workflows/ci.yml
biome.json
drizzle.config.ts
lefthook.yml
vite.config.ts
Dockerfile
```

## Setup commands

Run in this order when creating a new project:

```bash
# 1. Scaffold
bun create tsrouter-app@latest my-app
cd my-app

# 2. Core runtime deps
bun add hono drizzle-orm postgres better-auth zod
bun add @tanstack/react-form

# 3. Email, logging, monitoring, security
bun add resend react-email @react-email/components
bun add pino hono-pino
bun add @sentry/bun @sentry/tanstackstart-react
bun add hono-rate-limiter

# 4. Dev deps
bun add -d drizzle-kit @biomejs/biome lefthook

# 5. Tailwind v4
bun add tailwindcss @tailwindcss/vite

# 6. shadcn/ui (interactive)
bunx shadcn@latest init

# 7. Biome + lefthook
bunx biome init
bunx lefthook install

# 8. After writing src/lib/auth.ts, generate Better Auth schema
bunx @better-auth/cli generate --output src/db/auth-schema.ts

# 9. Generate and apply initial DB migration
bunx drizzle-kit generate
bunx drizzle-kit migrate
```

## Integration patterns

### Mount Hono inside Start

`src/routes/api/$.ts` is a catch-all that hands every `/api/*` request to Hono:

```ts
import { createFileRoute } from '@tanstack/react-router'
import { app } from '~/server/hono'

const handler = ({ request }: { request: Request }) => app.fetch(request)

export const Route = createFileRoute('/api/$')({
  server: {
    handlers: {
      GET: handler,
      POST: handler,
      PUT: handler,
      DELETE: handler,
      PATCH: handler,
    },
  },
})
```

`src/server/hono.ts`:

```ts
import { Hono } from 'hono'
import { auth } from '~/lib/auth'
import { postsRouter } from './routers/posts'

export const app = new Hono({ strict: false }).basePath('/api')

// Better Auth owns /api/auth/*
app.on(['GET', 'POST'], '/auth/*', (c) => auth.handler(c.req.raw))

// Feature routers
app.route('/posts', postsRouter)

export type AppType = typeof app   // export for Hono RPC client
```

### Drizzle with postgres.js

Always use the `postgres-js` adapter, never `node-postgres`:

```ts
// src/db/index.ts
import { drizzle } from 'drizzle-orm/postgres-js'
import postgres from 'postgres'
import * as schema from './schema'
import * as authSchema from './auth-schema'

const client = postgres(process.env.DATABASE_URL!, { prepare: false })
export const db = drizzle(client, {
  schema: { ...schema, ...authSchema },
})
```

`drizzle.config.ts`:

```ts
import { defineConfig } from 'drizzle-kit'

export default defineConfig({
  schema: ['./src/db/schema.ts', './src/db/auth-schema.ts'],
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: { url: process.env.DATABASE_URL! },
})
```

Migration workflow:

```bash
bunx drizzle-kit generate    # diff schema → SQL
bunx drizzle-kit migrate     # apply
bunx drizzle-kit studio      # GUI
```

### Better Auth

`src/lib/auth.ts`:

```ts
import { betterAuth } from 'better-auth'
import { drizzleAdapter } from 'better-auth/adapters/drizzle'
import { db } from '~/db'
import { sendEmail } from '~/lib/email'
import { ResetPasswordEmail, VerifyEmail } from '~/emails'

export const auth = betterAuth({
  database: drizzleAdapter(db, { provider: 'pg' }),
  emailAndPassword: {
    enabled: true,
    requireEmailVerification: true,
    sendResetPassword: async ({ user, url }) => {
      await sendEmail({ to: user.email, subject: 'Reset your password', react: ResetPasswordEmail({ url }) })
    },
  },
  emailVerification: {
    sendVerificationEmail: async ({ user, url }) => {
      await sendEmail({ to: user.email, subject: 'Verify your email', react: VerifyEmail({ url }) })
    },
  },
  // socialProviders: { github: { clientId, clientSecret } },
})
```

`src/lib/auth-client.ts`:

```ts
import { createAuthClient } from 'better-auth/react'

export const authClient = createAuthClient()
export const { signIn, signOut, signUp, useSession } = authClient
```

Reading the session on the server (server function or Hono handler):

```ts
const session = await auth.api.getSession({ headers: request.headers })
if (!session) throw new Error('unauthorized')
```

After every `better-auth` upgrade, re-run `bunx @better-auth/cli generate` and a new Drizzle migration.

### Email (Resend + React Email)

Resend is the only mail provider. Templates are React components in `src/emails/`.

```ts
// src/lib/email.ts
import { Resend } from 'resend'
import type { ReactElement } from 'react'

const resend = new Resend(process.env.RESEND_API_KEY!)

export async function sendEmail(opts: { to: string; subject: string; react: ReactElement }) {
  const { error } = await resend.emails.send({
    from: process.env.EMAIL_FROM!,
    ...opts,
  })
  if (error) throw new Error(`email send failed: ${error.message}`)
}
```

```tsx
// src/emails/VerifyEmail.tsx
import { Button, Html, Text } from '@react-email/components'

export function VerifyEmail({ url }: { url: string }) {
  return (
    <Html>
      <Text>Confirm your email to finish signing up.</Text>
      <Button href={url}>Verify email</Button>
    </Html>
  )
}
```

Required env: `RESEND_API_KEY`, `EMAIL_FROM` (a verified sender on your Resend domain).

### Logging (pino)

One pino instance, JSON in prod, pretty in dev. Always include a `requestId`.

```ts
// src/lib/logger.ts
import pino from 'pino'

export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  transport: process.env.NODE_ENV === 'development' ? { target: 'pino-pretty' } : undefined,
})
```

Plug into Hono so every request gets a child logger on `c.var.logger`:

```ts
import { pinoLogger } from 'hono-pino'
import { logger } from '~/lib/logger'

app.use('*', pinoLogger({ pino: logger }))
```

In handlers: `c.var.logger.info({ userId }, 'posted')`. Never `console.log` in committed code.

### Error monitoring (Sentry)

Initialise Sentry **first**, before any other imports that may throw.

```ts
// src/lib/sentry.ts
import * as Sentry from '@sentry/bun'

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 0.1,
})
```

Import it at the top of the server entry (`src/router.tsx` and the Hono `src/server/hono.ts`):

```ts
import '~/lib/sentry'
```

Wire Hono's error handler:

```ts
import * as Sentry from '@sentry/bun'

app.onError((err, c) => {
  Sentry.captureException(err)
  c.var.logger?.error({ err }, 'unhandled')
  return c.json({ error: 'internal' }, 500)
})
```

For the React side, follow `@sentry/tanstackstart-react`'s router instrumentation.

### Security middleware

CORS, security headers, and a rate limit on auth endpoints are non-negotiable.

```ts
// src/server/hono.ts
import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { secureHeaders } from 'hono/secure-headers'
import { rateLimiter } from 'hono-rate-limiter'
import { auth } from '~/lib/auth'

export const app = new Hono({ strict: false }).basePath('/api')

app.use('*', secureHeaders())
app.use('*', cors({ origin: process.env.PUBLIC_ORIGIN!, credentials: true }))

const authLimiter = rateLimiter({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  keyGenerator: (c) => c.req.header('x-forwarded-for') ?? c.req.header('cf-connecting-ip') ?? 'anon',
})
app.use('/auth/*', authLimiter)

app.on(['GET', 'POST'], '/auth/*', (c) => auth.handler(c.req.raw))
```

Behind Dokploy's Traefik, the client IP is in `x-forwarded-for`. Don't rate-limit by `c.req.remote` — every request looks like the proxy.

### TanStack Form + Zod

Define one schema, use it on both sides.

```ts
// src/schemas/post.ts
import { z } from 'zod'

export const postInput = z.object({
  title: z.string().min(1).max(200),
  body: z.string().min(1),
})
export type PostInput = z.infer<typeof postInput>
```

Form:

```tsx
import { useForm } from '@tanstack/react-form'
import { postInput } from '~/schemas/post'

const form = useForm({
  defaultValues: { title: '', body: '' },
  validators: { onSubmit: postInput },
  onSubmit: async ({ value }) => {
    // call server function or Hono RPC
  },
})
```

Server validation: parse with the same schema before touching the DB.

## Configuration

### Tailwind v4

`vite.config.ts`:

```ts
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vite'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'

export default defineConfig({
  plugins: [tanstackStart(), tailwindcss()],
})
```

`src/styles/app.css`:

```css
@import "tailwindcss";

@theme {
  --color-brand: oklch(0.7 0.18 250);
  --font-display: "Inter", sans-serif;
  /* design tokens live here, not in a JS config */
}
```

There is **no `tailwind.config.js`** in v4. shadcn/ui must be installed in its v4-compatible mode.

### Biome

`biome.json`:

```json
{
  "$schema": "https://biomejs.dev/schemas/2.0.0/schema.json",
  "files": {
    "ignoreUnknown": true,
    "includes": ["**", "!**/drizzle/**", "!**/.output/**", "!**/node_modules/**"]
  },
  "formatter": {
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 100
  },
  "linter": {
    "enabled": true,
    "rules": { "recommended": true }
  },
  "javascript": {
    "formatter": { "quoteStyle": "single", "semicolons": "asNeeded" }
  }
}
```

Commands:

```bash
bunx biome check --write     # lint + format in one shot
bunx biome ci                # CI mode, no writes
```

### TypeScript

`tsconfig.json` must have:

- `"strict": true`
- `"moduleResolution": "bundler"`
- `"verbatimModuleSyntax": true`
- Path alias `"~/*": ["./src/*"]`

### lefthook (pre-commit)

One canonical pre-commit hook: Biome on staged files. No husky, no pre-commit-the-tool.

`lefthook.yml`:

```yaml
pre-commit:
  parallel: true
  commands:
    biome:
      glob: '*.{ts,tsx,js,jsx,json,jsonc}'
      run: bunx biome check --write --no-errors-on-unmatched {staged_files}
      stage_fixed: true
```

Install once per clone: `bunx lefthook install`.

### GitHub Actions CI

One workflow file, runs on every PR and push to main. Mirrors the same checks lefthook runs locally, plus typecheck and tests.

`.github/workflows/ci.yml`:

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest
      - run: bun install --frozen-lockfile
      - run: bunx biome ci
      - run: bunx tsc --noEmit
      - run: bun test
```

Add a `services: postgres:` block if your tests touch the database — never run unit tests against a shared dev DB.

## Testing

Use Bun's built-in test runner. No Jest, no Vitest.

```ts
// src/lib/foo.test.ts
import { describe, expect, test } from 'bun:test'

describe('foo', () => {
  test('adds', () => {
    expect(1 + 1).toBe(2)
  })
})
```

Commands:

```bash
bun test              # run once
bun test --watch      # watch mode
bun test --coverage   # with coverage
```

For DB-touching tests, run a real Postgres in Docker on a test port and reset between suites. Do not mock the ORM.

## Deployment: Dokploy on VPS

Dokploy is a self-hosted PaaS that runs on a VPS, pulls from Git, and builds with Docker. Goal: zero vendor lock-in, all infra owned.

### Dockerfile

```dockerfile
FROM oven/bun:1-alpine AS base
WORKDIR /app

FROM base AS deps
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

FROM base AS build
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN bun run build

FROM base AS runtime
ENV NODE_ENV=production
COPY --from=build /app/.output ./.output
COPY --from=build /app/package.json ./
EXPOSE 3000
CMD ["bun", "run", "./.output/server/index.mjs"]
```

### Dokploy steps

1. Install Dokploy on the VPS:
   ```bash
   curl -sSL https://dokploy.com/install.sh | sh
   ```
2. In the Dokploy UI, create an Application. Point it at the Git repository.
3. Build type: **Dockerfile**. Dokploy reads the `Dockerfile` at the repo root.
4. Add a **Postgres service** in Dokploy. Copy the internal connection string.
5. Set environment variables on the application:
   - `DATABASE_URL` — use the **internal service hostname**, not `localhost`
   - `BETTER_AUTH_SECRET` — generate with `openssl rand -base64 32`
   - `BETTER_AUTH_URL` — the public origin (e.g. `https://app.example.com`)
   - `PUBLIC_ORIGIN` — same value, used by the CORS middleware
   - `RESEND_API_KEY` — from Resend dashboard
   - `EMAIL_FROM` — verified sender, e.g. `auth@example.com`
   - `SENTRY_DSN` — from the Sentry project
   - `LOG_LEVEL` — `info` in prod, `debug` for incident response
6. Enable HTTPS via the built-in Traefik + Let's Encrypt. Add the domain in the Domains tab.
7. Enable auto-deploy on Git push (webhook).

### Migrations on deploy

Add a release step that runs `bunx drizzle-kit migrate` before the new container takes traffic. Either:

- Use Dokploy's pre-deploy command, or
- Add a `release.sh` invoked from a wrapper `CMD`.

## Gotchas

- **Tailwind v4** has no JS config; tokens go in CSS `@theme`. Only use the v4-compatible shadcn components.
- **Postgres driver**: `postgres` (postgres.js), never `pg`. Drizzle adapter is `drizzle-orm/postgres-js`.
- **Hono mount**: the catch-all file must be `src/routes/api/$.ts` and return `app.fetch(request)`. Don't try to use Start's server functions for the same paths Hono owns.
- **Better Auth tables** are generated; do not hand-edit `src/db/auth-schema.ts`. Re-generate after upgrades and create a new Drizzle migration.
- **Biome does not sort Tailwind classes**. If class ordering matters, add `prettier-plugin-tailwindcss` for that single concern, or accept unsorted classes.
- **Bun lockfile** is `bun.lock` (text, since Bun 1.1), not `bun.lockb`. Commit it.
- **Dokploy + Postgres on the same VPS**: use the internal service hostname (e.g. `my-app-db`), not `localhost`, in `DATABASE_URL`.
- **Server functions vs Hono**: pick one per route. Mixed ownership of the same path causes hard-to-debug 404s.
- **Edge runtimes**: this stack targets Node-compatible runtime (Bun server). It is not designed for Cloudflare Workers; some Better Auth and `postgres` features assume long-lived connections.
- **Sentry must init first**: `import '~/lib/sentry'` has to be the *first* import in the server entry. Otherwise instrumented modules load before Sentry hooks them and you lose half your traces.
- **Resend sender domain**: `EMAIL_FROM` must be on a domain verified in Resend, not just any address. Better Auth's verify/reset flows fail silently otherwise — only the Resend dashboard shows the rejection.
- **Rate-limit key behind a proxy**: behind Dokploy's Traefik, key by `x-forwarded-for`, not `c.req.remote` (always the proxy). Same applies to any reverse proxy.
- **`console.log` in committed code**: forbidden. Use `c.var.logger` (Hono) or the imported `logger` (server functions). Otherwise lines bypass pino's JSON formatting and the structured-log pipeline.
- **`.env` in Docker**: do not bake env into the image. Set them in Dokploy's UI so secrets stay out of the image layer.

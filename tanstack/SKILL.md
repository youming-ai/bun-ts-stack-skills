---
name: tanstack
description: Full-stack TypeScript conventions for projects built on the Bun + TanStack Start ecosystem. Covers project scaffolding, directory structure, integration patterns, configuration, and deployment for the canonical stack of Bun runtime, TanStack Start, Vite, Hono, Drizzle ORM, PostgreSQL, Better Auth, Tailwind CSS v4, shadcn/ui, TanStack Form, Zod, Resend, pino, Sentry, lefthook, GitHub Actions, Biome, bun test, and Dokploy. Use this skill whenever the user is setting up, configuring, scaffolding, writing code, or deploying a project that mentions ANY of these technologies — including phrases like "set up a new project", "add auth", "send emails", "add logging", "rate limit", "CI pipeline", "Drizzle schema", "mount Hono", "deploy to Dokploy", "my stack", or "this project" in the context of Bun + TanStack work. Trigger this even when only a subset of these technologies is mentioned, since it is the project's canonical stack and other choices should be checked against it.
---

# TanStack Bun Stack

Conventions for full-stack TypeScript apps on Bun + TanStack Start. Source of truth for stack choices, layout, integrations, and deploy. Deviate only with explicit reason.

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

- Bun is runtime, package manager, test runner, script runner. Never `npm` / `pnpm` / `yarn` / `node`.
- TypeScript `strict: true` everywhere.
- Prefer Bun built-ins: `Bun.password`, `bun:sqlite`, `Bun.s3`, `Bun.file`, native `fetch`, `bun:test`.
- Do not install: `dotenv`, `ts-node`, `tsx`, `nodemon`, `jest`, `vitest`, `bcrypt`, `argon2`, `pg`, `better-sqlite3`, `node-fetch`, `eslint`, `prettier`, `nodemailer`, `husky`, `pre-commit`, `winston`, `bunyan`.

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

- CRUD → **server functions** inline with components.
- Middleware, OpenAPI, RPC, external API surface → **Hono** at `/api/*`.
- **Better Auth** plugs into Hono as handler, Drizzle as schema.
- One **Zod schema** per concept in `src/schemas/`, shared by Hono / Form / Drizzle.

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
│   ├── index.ts                  # Drizzle client
│   ├── schema.ts                 # business tables
│   └── auth-schema.ts            # Better Auth (CLI-generated, do not edit)
├── lib/
│   ├── auth.ts, auth-client.ts
│   ├── email.ts                  # Resend wrapper
│   ├── logger.ts                 # pino
│   └── sentry.ts                 # init (imported first)
├── emails/                       # React Email templates
├── schemas/                      # shared Zod schemas
├── components/{ui,forms}/
├── styles/app.css                # @import "tailwindcss"
└── router.tsx
drizzle/                          # generated migrations
.github/workflows/ci.yml
biome.json, drizzle.config.ts, lefthook.yml, vite.config.ts, Dockerfile
```

## Setup

```bash
bun create tsrouter-app@latest my-app && cd my-app

# Runtime
bun add hono drizzle-orm postgres better-auth zod @tanstack/react-form
bun add resend react-email @react-email/components
bun add pino hono-pino @sentry/bun @sentry/tanstackstart-react hono-rate-limiter
bun add tailwindcss @tailwindcss/vite

# Dev
bun add -d drizzle-kit @biomejs/biome lefthook

# Init
bunx shadcn@latest init
bunx biome init
bunx lefthook install

# After writing src/lib/auth.ts
bunx @better-auth/cli generate --output src/db/auth-schema.ts

# DB
bunx drizzle-kit generate && bunx drizzle-kit migrate
```

## Integration patterns

### Mount Hono inside Start

`src/routes/api/$.ts`:

```ts
import { createFileRoute } from '@tanstack/react-router'
import { app } from '~/server/hono'

const handler = ({ request }: { request: Request }) => app.fetch(request)

export const Route = createFileRoute('/api/$')({
  server: {
    handlers: { GET: handler, POST: handler, PUT: handler, DELETE: handler, PATCH: handler },
  },
})
```

`src/server/hono.ts` — see *Security middleware* for the production version that wires CORS, secure headers, and rate limiting.

### Drizzle with postgres.js

```ts
// src/db/index.ts
import { drizzle } from 'drizzle-orm/postgres-js'
import postgres from 'postgres'
import * as schema from './schema'
import * as authSchema from './auth-schema'

const client = postgres(process.env.DATABASE_URL!, { prepare: false })
export const db = drizzle(client, { schema: { ...schema, ...authSchema } })
```

```ts
// drizzle.config.ts
import { defineConfig } from 'drizzle-kit'

export default defineConfig({
  schema: ['./src/db/schema.ts', './src/db/auth-schema.ts'],
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: { url: process.env.DATABASE_URL! },
})
```

Workflow: `bunx drizzle-kit generate` → `migrate`; `studio` for GUI.

### Better Auth

```ts
// src/lib/auth.ts
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
    sendResetPassword: async ({ user, url }) =>
      sendEmail({ to: user.email, subject: 'Reset your password', react: ResetPasswordEmail({ url }) }),
  },
  emailVerification: {
    sendVerificationEmail: async ({ user, url }) =>
      sendEmail({ to: user.email, subject: 'Verify your email', react: VerifyEmail({ url }) }),
  },
})
```

```ts
// src/lib/auth-client.ts
import { createAuthClient } from 'better-auth/react'
export const authClient = createAuthClient()
export const { signIn, signOut, signUp, useSession } = authClient
```

Read session on the server: `await auth.api.getSession({ headers: request.headers })`. Re-run the CLI + a new Drizzle migration after every Better Auth upgrade.

### Email (Resend + React Email)

```ts
// src/lib/email.ts
import { Resend } from 'resend'
import type { ReactElement } from 'react'

const resend = new Resend(process.env.RESEND_API_KEY!)

export async function sendEmail(opts: { to: string; subject: string; react: ReactElement }) {
  const { error } = await resend.emails.send({ from: process.env.EMAIL_FROM!, ...opts })
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

Env: `RESEND_API_KEY`, `EMAIL_FROM` (verified Resend sender).

### Logging (pino)

```ts
// src/lib/logger.ts
import pino from 'pino'

export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  transport: process.env.NODE_ENV === 'development' ? { target: 'pino-pretty' } : undefined,
})
```

Mount on Hono so every request has `c.var.logger`:

```ts
import { pinoLogger } from 'hono-pino'
app.use('*', pinoLogger({ pino: logger }))
```

Use `c.var.logger.info({ userId }, 'posted')` in handlers. No `console.log` in committed code.

### Error monitoring (Sentry)

Init **first** — before any other server-side import.

```ts
// src/lib/sentry.ts
import * as Sentry from '@sentry/bun'

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 0.1,
})
```

`import '~/lib/sentry'` at the top of `src/router.tsx` and `src/server/hono.ts`. Hono error handler:

```ts
import * as Sentry from '@sentry/bun'

app.onError((err, c) => {
  Sentry.captureException(err)
  c.var.logger?.error({ err }, 'unhandled')
  return c.json({ error: 'internal' }, 500)
})
```

React side: follow `@sentry/tanstackstart-react` router instrumentation.

### Security middleware

CORS, secure headers, and a rate limit on `/auth/*` are non-negotiable.

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
app.use('/auth/*', rateLimiter({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  keyGenerator: (c) => c.req.header('x-forwarded-for') ?? 'anon',
}))

app.on(['GET', 'POST'], '/auth/*', (c) => auth.handler(c.req.raw))
```

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

### Tailwind v4

```ts
// vite.config.ts
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vite'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'

export default defineConfig({ plugins: [tanstackStart(), tailwindcss()] })
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

`tsconfig.json`: `strict`, `moduleResolution: "bundler"`, `verbatimModuleSyntax: true`, alias `"~/*": ["./src/*"]`.

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
```

Add a `services: postgres:` block if tests touch the DB.

## Testing

```ts
import { describe, expect, test } from 'bun:test'
test('adds', () => { expect(1 + 1).toBe(2) })
```

`bun test`, `--watch`, `--coverage`. DB tests: real Postgres in Docker on a test port, reset between suites, never mock the ORM.

## Deployment: Dokploy

Self-hosted PaaS: pulls Git, builds Docker, runs on a VPS.

```dockerfile
# Dockerfile
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

Setup:

1. Install Dokploy: `curl -sSL https://dokploy.com/install.sh | sh`
2. Application → point at repo → build type **Dockerfile**.
3. Add a Postgres service. Copy the internal connection string.
4. Env vars:
   - `DATABASE_URL` — internal hostname, never `localhost`
   - `BETTER_AUTH_SECRET` — `openssl rand -base64 32`
   - `BETTER_AUTH_URL` / `PUBLIC_ORIGIN` — public origin
   - `RESEND_API_KEY`, `EMAIL_FROM` — verified Resend sender
   - `SENTRY_DSN`, `LOG_LEVEL`
5. Enable HTTPS (Traefik + Let's Encrypt). Add domain.
6. Enable auto-deploy on Git push.
7. Pre-deploy: `bunx drizzle-kit migrate`.

## Gotchas

- **Tailwind v4** has no JS config — tokens in CSS `@theme`. Use v4-compatible shadcn only.
- **Postgres driver**: `postgres-js`, never `pg`. Adapter is `drizzle-orm/postgres-js`.
- **Hono mount**: catch-all must be `src/routes/api/$.ts`. Don't share paths with server functions — silent 404s.
- **Better Auth tables** are generated; never hand-edit `src/db/auth-schema.ts`. Regenerate + new migration after upgrades.
- **Biome doesn't sort Tailwind classes**. Accept the order or add `prettier-plugin-tailwindcss` for that one concern.
- **Bun lockfile** is `bun.lock` (text). Commit it.
- **`DATABASE_URL` on Dokploy** uses the internal service hostname, never `localhost`.
- **Edge runtimes**: not designed for Cloudflare Workers — Better Auth and `postgres` assume long-lived connections.
- **Sentry init order**: `import '~/lib/sentry'` must be the first import in the server entry, or instrumented modules load before the hooks attach.
- **Resend sender**: `EMAIL_FROM` must be on a verified domain — Better Auth flows fail silently otherwise; check the Resend dashboard.
- **Rate-limit key**: behind Traefik, key by `x-forwarded-for`, never `c.req.remote` (always the proxy).
- **`console.log` is banned** in committed code — use `c.var.logger` (Hono) or the imported `logger` (server fns).
- **Don't bake `.env` into the image**. Set in Dokploy UI so secrets stay out of the image layer.

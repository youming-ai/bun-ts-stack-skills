---
name: astro
description: Full-stack TypeScript conventions for content-driven sites built on Bun + Astro, deployed to Cloudflare Workers. Canonical stack — Bun (dev tooling), Astro 5, Content Collections, MDX, React islands, Astro Actions, Drizzle + self-hosted PostgreSQL via Cloudflare Hyperdrive (optional), Better Auth + Cloudflare KV (optional), Tailwind v4, shadcn/ui, Zod, Resend, pino, Sentry, lefthook, GitHub Actions, Biome, bun test, wrangler. Use whenever the user is scaffolding, writing, configuring, or deploying a content-driven site mentioning ANY of these — including "blog", "docs site", "marketing site", "landing page", "portfolio", "content collection", "MDX", "Astro action", "RSS feed", "sitemap", "send emails", "add logging", "CI pipeline", "deploy to Cloudflare", "Workers", "Hyperdrive", or Astro in a Bun + TS context. Trigger even when only one technology is mentioned. This is the content-site counterpart to `tanstack`, which covers app-driven projects.
---

# Astro Bun Stack

Conventions for content-driven sites (blogs, docs, marketing, portfolios) on Bun + Astro, deployed to Cloudflare Workers. Counterpart to `tanstack` — pick this when SEO and pages matter; pick `tanstack` when state and login matter. Both deploy the same way: Cloudflare Workers + KV + Hyperdrive.

## Stack

| Layer          | Choice                                                        |
| -------------- | ------------------------------------------------------------- |
| Dev runtime    | Bun (package manager, test, scripts)                          |
| Prod runtime   | Cloudflare Workers (V8 isolate), `@astrojs/cloudflare` adapter |
| Language       | TypeScript (strict)                                           |
| Framework      | Astro 5 (LTS)                                                 |
| Content        | Content Collections (`glob()` loader) + MDX                   |
| Server         | Astro Actions (typed, Zod-validated)                          |
| Interactive    | React islands (`@astrojs/react`) — only when needed           |
| ORM            | Drizzle + Drizzle Kit (optional)                              |
| Database       | Self-hosted PostgreSQL via Cloudflare Hyperdrive (optional)   |
| KV             | Cloudflare KV — sessions, rate-limit, cache (optional)        |
| Auth           | Better Auth (optional)                                        |
| CSS            | Tailwind v4 (`@tailwindcss/vite`)                             |
| UI             | shadcn/ui (React islands) + lucide-react                      |
| Validation     | Zod                                                           |
| SEO            | `@astrojs/sitemap` + `@astrojs/rss` + `<SEO>` component       |
| Search         | Pagefind (static, build-time index)                           |
| Email          | Resend + React Email (only if site sends mail)                |
| Logging        | pino (in `src/middleware.ts`)                                 |
| Monitoring     | Sentry (`@sentry/astro`)                                      |
| Security       | Astro middleware: security headers + KV rate limit            |
| Lint/Format    | Biome                                                         |
| Git hooks      | lefthook                                                      |
| Test           | `bun test`                                                    |
| CI/CD          | GitHub Actions + `wrangler deploy`                            |
| Deploy         | Cloudflare Workers                                            |

### Non-negotiables

- Bun is the dev runtime: package manager, test runner, script runner. Never `npm` / `pnpm` / `yarn` / `node`.
- Production runs on **Cloudflare Workers** via `@astrojs/cloudflare`. Server code (SSR pages, Actions, middleware) must be Workers-compatible: Web-standard APIs, no Node built-ins unless `nodejs_compat`.
- **Zero JS by default**: Astro renders static HTML; interactive bits are explicit islands with `client:*`. If `.astro` can do it, don't reach for React.
- TypeScript `strict: true`.
- Do not install: `dotenv`, `ts-node`, `tsx`, `nodemon`, `jest`, `vitest`, `bcrypt`, `argon2`, `pg`, `eslint`, `prettier`, `nodemailer`, `husky`, `pre-commit`, `winston`, `bunyan`, `@astrojs/tailwind` (deprecated), `@astrojs/node`.

### When to add what

| Need                                      | Add                                            |
| ----------------------------------------- | ---------------------------------------------- |
| Pure static blog / docs / marketing       | nothing extra                                  |
| Comments, likes, newsletter signup        | `@astrojs/react` + Astro Actions               |
| Persisted data                            | Drizzle + Postgres via Hyperdrive              |
| Login / sessions                          | Better Auth + KV                               |
| Site search                               | Pagefind                                       |

## Architecture

```
                      Build time                          Request time
                      ──────────                          ────────────

  Content Collections ─► prerender ─► static HTML ──────►  Cloudflare CDN  ──►  Browser
  (default)                                                 (no Worker run)

  Pages (SSR)  ───────────────────────────────────────►  Cloudflare Workers
  export const prerender = false                                │
                                                          @astrojs/cloudflare
                                                                │
                                                          stream HTML  ────────►  Browser
                                                                ▲
                                                                │  bindings = Astro.locals.runtime.env
                                                                │
  Form / island ──► Astro Action ──POST /_actions/*──────►  Worker endpoint
                                                                │
                                                          action handler
                                                                │
                                                                ▼
                                                          Drizzle ──► Hyperdrive ──► PostgreSQL
                                                          Better Auth + KV          (self-hosted)
```

Most pages **prerender** to static HTML and serve from the CDN with no Worker run. Routes with `export const prerender = false` run on Workers. Actions always run server-side. Secrets and bindings (Hyperdrive, KV) come from `Astro.locals.runtime.env` at request time — never module scope.

## Project structure

```
src/
├── pages/
│   ├── index.astro
│   ├── blog/{index,[...slug]}.astro
│   ├── rss.xml.ts
│   └── 404.astro
├── content/{blog,docs}/         # Content Collections sources
├── content.config.ts            # collections + Zod schemas (Astro 5+)
├── actions/index.ts             # Astro Actions
├── middleware.ts                # security headers + pino + KV rate limit
├── layouts/                     # BaseLayout, PostLayout, ...
├── components/
│   ├── *.astro                  # default — no JS
│   ├── ui/                      # shadcn/ui (React islands)
│   └── react/                   # custom React islands
├── lib/
│   ├── db.ts                    # Drizzle client factory (if DB)
│   ├── auth.ts                  # Better Auth factory (if auth)
│   ├── email.ts                 # Resend (if mail)
│   └── logger.ts                # pino
├── emails/                      # React Email templates
├── db/schema.ts                 # Drizzle schema (if DB)
├── schemas/
└── styles/global.css            # @import "tailwindcss"
public/{favicon.svg,robots.txt,og/}
.github/workflows/ci.yml
astro.config.mjs, biome.json, lefthook.yml, wrangler.toml
```

## Setup

```bash
bun create astro@latest my-site && cd my-site

# Core
bunx astro add tailwind
bunx astro add mdx sitemap
bun add @astrojs/rss zod

# Interactivity (only when needed)
bunx astro add react
bunx shadcn@latest init

# Server runtime — Cloudflare Workers
bunx astro add cloudflare
bun add -d wrangler @cloudflare/workers-types

# Quality
bun add -d @biomejs/biome lefthook
bunx biome init && bunx lefthook install

# Logging + monitoring
bun add pino
bunx astro add @sentry/astro

# Optional
bun add resend react-email @react-email/components                       # email
bun add drizzle-orm postgres better-auth && bun add -d drizzle-kit       # DB + auth
bun add -d pagefind                                                      # search

# Provision Hyperdrive over your self-hosted Postgres + a KV namespace
bunx wrangler hyperdrive create my-site-db --connection-string="postgres://user:pass@host:5432/db"
bunx wrangler kv namespace create KV
```

## Integration patterns

### Content Collections

Schema is the source of truth for frontmatter — Astro validates at build time and generates types.

```ts
// src/content.config.ts
import { defineCollection, z } from 'astro:content'
import { glob } from 'astro/loaders'

const blog = defineCollection({
  loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/blog' }),
  schema: ({ image }) =>
    z.object({
      title: z.string().max(120),
      description: z.string().max(200),
      pubDate: z.coerce.date(),
      updatedDate: z.coerce.date().optional(),
      cover: image().optional(),
      tags: z.array(z.string()).default([]),
      draft: z.boolean().default(false),
    }),
})

export const collections = { blog }
```

Listing:

```astro
---
// src/pages/blog/index.astro
import { getCollection } from 'astro:content'
const posts = (await getCollection('blog', ({ data }) => !data.draft))
  .sort((a, b) => b.data.pubDate.valueOf() - a.data.pubDate.valueOf())
---
<ul>
  {posts.map((p) => <li><a href={`/blog/${p.id}`}>{p.data.title}</a></li>)}
</ul>
```

Single post via `[...slug].astro`:

```astro
---
import { getCollection, render } from 'astro:content'

export async function getStaticPaths() {
  const posts = await getCollection('blog', ({ data }) => !data.draft)
  return posts.map((post) => ({ params: { slug: post.id }, props: { post } }))
}

const { post } = Astro.props
const { Content } = await render(post)
---
<Content />
```

### Astro Actions

Prefer Actions over API routes — Zod validation, typed RPC, progressive HTML forms, all free. Bindings arrive via `ctx.locals.runtime.env`.

```ts
// src/actions/index.ts
import { defineAction, ActionError } from 'astro:actions'
import { z } from 'astro:schema'

export const server = {
  subscribe: defineAction({
    accept: 'form',
    input: z.object({ email: z.string().email() }),
    handler: async ({ email }) => ({ ok: true as const }),
  }),
  like: defineAction({
    input: z.object({ postId: z.string() }),
    handler: async ({ postId }, ctx) => {
      if (!ctx.locals.user) throw new ActionError({ code: 'UNAUTHORIZED' })
      const { createDb } = await import('~/lib/db')
      const db = createDb(ctx.locals.runtime.env.HYPERDRIVE.connectionString)
      // ...write with db
      return { likes: 42 }
    },
  }),
}
```

From a React island:

```tsx
import { actions } from 'astro:actions'

export function LikeButton({ postId }: { postId: string }) {
  return <button onClick={async () => {
    const { data, error } = await actions.like({ postId })
    if (!error) console.log(data.likes)
  }}>Like</button>
}
```

From an HTML form (works without JS):

```astro
---
import { actions } from 'astro:actions'
const result = Astro.getActionResult(actions.subscribe)
---
<form method="POST" action={actions.subscribe}>
  <input name="email" type="email" required />
  <button type="submit">Subscribe</button>
</form>
{result?.data?.ok && <p>Subscribed.</p>}
```

### React islands

```astro
---
import { LikeButton } from '~/components/react/LikeButton'
---
<LikeButton postId={post.id} client:idle />
```

| Directive        | When                                          |
| ---------------- | --------------------------------------------- |
| `client:load`    | Critical, above-the-fold                      |
| `client:idle`    | Default — hydrates after page load            |
| `client:visible` | Below the fold                                |
| `client:only`    | Browser-only deps (can't SSR)                 |

`.astro` by default; React only when interactive.

### Tailwind v4 + Cloudflare adapter

```ts
// astro.config.mjs
import { defineConfig } from 'astro/config'
import tailwindcss from '@tailwindcss/vite'
import mdx from '@astrojs/mdx'
import sitemap from '@astrojs/sitemap'
import react from '@astrojs/react'
import cloudflare from '@astrojs/cloudflare'

export default defineConfig({
  site: 'https://example.com',
  integrations: [mdx(), sitemap(), react()],
  adapter: cloudflare(),
  vite: { plugins: [tailwindcss()] },
})
```

```css
/* src/styles/global.css */
@import "tailwindcss";
@plugin "@tailwindcss/typography";

@theme {
  --color-brand: oklch(0.7 0.18 250);
}

@custom-variant dark (&:where(.dark, .dark *));
```

Import once from a layout: `import '~/styles/global.css'`. No `tailwind.config.js` — tokens in `@theme`. shadcn/ui only after `@astrojs/react`.

### Drizzle over Hyperdrive (optional)

Bindings aren't available at module load on Workers — build the client per request from the Hyperdrive binding's connection string.

```ts
// src/lib/db.ts
import { drizzle } from 'drizzle-orm/postgres-js'
import postgres from 'postgres'
import * as schema from '~/db/schema'

// connStr: runtime.env.HYPERDRIVE.connectionString on Workers
export function createDb(connStr: string) {
  const client = postgres(connStr, { prepare: false, max: 5 })
  return drizzle(client, { schema })
}
export type DB = ReturnType<typeof createDb>
```

`drizzle.config.ts` uses `process.env.DATABASE_URL` — migrations connect **directly** to Postgres, never through Hyperdrive.

### Better Auth + KV (optional)

Request-scoped like the DB. KV backs sessions and Better Auth's rate limiting so they survive across isolates.

```ts
// src/lib/auth.ts
import { betterAuth } from 'better-auth'
import { drizzleAdapter } from 'better-auth/adapters/drizzle'
import type { DB } from '~/lib/db'
import { sendEmail } from '~/lib/email'
import { ResetPasswordEmail, VerifyEmail } from '~/emails'

// env is the Workers bindings object (`locals.runtime.env`) — pass it straight through
export function createAuth(db: DB, env: Env) {
  return betterAuth({
    database: drizzleAdapter(db, { provider: 'pg' }),
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
// src/pages/api/auth/[...all].ts
import { createDb } from '~/lib/db'
import { createAuth } from '~/lib/auth'
import type { APIRoute } from 'astro'

export const prerender = false
export const ALL: APIRoute = ({ request, locals }) => {
  const env = locals.runtime.env
  const db = createDb(env.HYPERDRIVE.connectionString)
  const auth = createAuth(db, env)
  return auth.handler(request)
}
```

Session: `await auth.api.getSession({ headers: Astro.request.headers })` (build `auth` per request). Wire `sendResetPassword`/`sendVerificationEmail` to Resend — flows fail silently otherwise. Re-run `bunx @better-auth/cli generate` + a new migration after every upgrade.

### Email (Resend + React Email)

Only when the site sends mail. API key comes from the runtime env, passed in.

```ts
// src/lib/email.ts
import { Resend } from 'resend'
import type { ReactElement } from 'react'

export async function sendEmail(opts: { to: string; subject: string; react: ReactElement }, apiKey: string, from: string) {
  const { error } = await new Resend(apiKey).emails.send({ from, ...opts })
  if (error) throw new Error(`email send failed: ${error.message}`)
}
```

From an Action:

```ts
contact: defineAction({
  accept: 'form',
  input: z.object({ email: z.string().email(), message: z.string().min(1).max(2000) }),
  handler: async ({ email, message }, ctx) => {
    const env = ctx.locals.runtime.env
    await sendEmail({ to: 'team@example.com', subject: `Contact from ${email}`, react: ContactEmail({ email, message }) }, env.RESEND_API_KEY, env.EMAIL_FROM)
    return { ok: true as const }
  },
}),
```

Bindings: `RESEND_API_KEY`, `EMAIL_FROM` (verified Resend sender).

### Logging (pino)

`console.log` is fine in build scripts; in SSR / Actions / middleware, use pino.

```ts
// src/lib/logger.ts
import pino from 'pino'

export const logger = pino({ level: process.env.LOG_LEVEL ?? 'info' })
```

Mounted in middleware below. On Workers, view logs with `wrangler tail`. Don't ship `pino-pretty` (dev-only transport).

### Error monitoring (Sentry)

`bunx astro add @sentry/astro` wires client + server.

```ts
// astro.config.mjs
import sentry from '@sentry/astro'

export default defineConfig({
  integrations: [
    sentry({
      dsn: process.env.SENTRY_DSN,
      environment: process.env.MODE,
      sourceMapsUploadOptions: { project: 'my-site', authToken: process.env.SENTRY_AUTH_TOKEN },
    }),
    // ...
  ],
})
```

`astro.config.mjs` runs at build time under Node — use `process.env` here. In `src/` use `import.meta.env` / `runtime.env`. Errors in Actions and SSR pages are captured automatically.

### Security middleware

`src/middleware.ts` runs on every server-rendered request (prerendered pages skip it). Security headers, request logging, and a KV-backed rate limit on auth/Actions.

```ts
// src/middleware.ts
import { defineMiddleware } from 'astro:middleware'
import { logger } from '~/lib/logger'

// KV-backed so counts survive across isolates (approximate — KV is eventually consistent)
async function rateLimit(kv: KVNamespace, key: string, limit = 20, windowSec = 900) {
  const n = Number((await kv.get(key)) ?? 0) + 1
  await kv.put(key, String(n), { expirationTtl: windowSec })
  return n <= limit
}

export const onRequest = defineMiddleware(async (ctx, next) => {
  const start = performance.now()
  const ip = ctx.request.headers.get('cf-connecting-ip') ?? 'anon'

  if (ctx.url.pathname.startsWith('/api/auth') || ctx.url.pathname.startsWith('/_actions/')) {
    const kv = ctx.locals.runtime.env.KV
    if (!(await rateLimit(kv, `${ip}:${ctx.url.pathname}`))) return new Response('Too many requests', { status: 429 })
  }

  const res = await next()
  res.headers.set('X-Frame-Options', 'DENY')
  res.headers.set('X-Content-Type-Options', 'nosniff')
  res.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin')
  res.headers.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()')
  res.headers.set('Content-Security-Policy',
    "default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline'; script-src 'self'")

  logger.info({ method: ctx.request.method, path: ctx.url.pathname, status: res.status, ms: Math.round(performance.now() - start) })
  return res
})
```

Use `cf-connecting-ip` for the real client IP. For exact per-key counts use a Durable Object. Tighten CSP if you use `is:inline` or third-party widgets. Prerendered pages skip middleware — set static headers in Cloudflare's response rules if needed.

### SEO + RSS + Sitemap

Sitemap is automatic once `@astrojs/sitemap` is installed and `site` is set.

```ts
// src/pages/rss.xml.ts
import rss from '@astrojs/rss'
import { getCollection } from 'astro:content'

export async function GET(context) {
  const posts = await getCollection('blog', ({ data }) => !data.draft)
  return rss({
    title: 'My Blog',
    description: 'Thoughts and notes',
    site: context.site!,
    items: posts.map((p) => ({
      title: p.data.title,
      description: p.data.description,
      pubDate: p.data.pubDate,
      link: `/blog/${p.id}/`,
    })),
  })
}
```

Meta tags: a small `<SEO>` component reading from frontmatter — title, description, canonical, OG, Twitter.

### Pagefind (optional)

Build-time static index from the built HTML.

```json
{ "scripts": { "build": "astro build && pagefind --site dist" } }
```

```astro
<link rel="stylesheet" href="/pagefind/pagefind-ui.css" />
<div id="search"></div>
<script>
  import('/pagefind/pagefind-ui.js').then(({ PagefindUI }) => new PagefindUI({ element: '#search' }))
</script>
```

## Configuration

### TypeScript

`tsconfig.json` extends `astro/tsconfigs/strict`, adds alias `"~/*": ["./src/*"]` + `"verbatimModuleSyntax": true`, and `"types": ["@cloudflare/workers-types"]` so `KVNamespace` / `Hyperdrive` binding types resolve.

### Environment variables

| Scope | Convention | Access |
|---|---|---|
| Public (client-safe) | `PUBLIC_` prefix | `import.meta.env.PUBLIC_FOO` |
| Server secrets | Worker binding | `Astro.locals.runtime.env.FOO` (pages) / `ctx.locals.runtime.env.FOO` (Actions, middleware) |

Secrets (`BETTER_AUTH_SECRET`, `RESEND_API_KEY`, `SENTRY_DSN`) are Worker secrets — `wrangler secret put NAME`, never in `wrangler.toml` or the client bundle. The `Env` type is generated by `bunx wrangler types` — re-run after editing `wrangler.toml`.

### Biome

```json
{
  "$schema": "https://biomejs.dev/schemas/2.0.0/schema.json",
  "files": { "ignoreUnknown": true, "includes": ["**", "!**/dist/**", "!**/.astro/**", "!**/node_modules/**"] },
  "formatter": { "indentStyle": "space", "indentWidth": 2, "lineWidth": 100 },
  "linter": { "enabled": true, "rules": { "recommended": true } },
  "javascript": { "formatter": { "quoteStyle": "single", "semicolons": "asNeeded" } }
}
```

`.astro` files aren't first-class in Biome yet — format their `<script>`/`<style>` blocks manually or with Prettier-Astro. `.ts`/`.tsx` are covered. Use `bunx biome check --write` and `bunx astro check` (type-checks `.astro`).

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
      - run: bunx astro check
      - run: bun test
      - run: bun run build
  deploy:
    needs: check
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
      - run: bun install --frozen-lockfile
      - run: bun run build          # emit dist/ (Worker + assets) before deploy
      - run: bunx wrangler deploy
        env: { CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }} }
```

`astro check` is the only place `.astro` gets type-checked. Building catches MDX / Content Collection schema mismatches. If migrations: `bunx drizzle-kit migrate` (against `DATABASE_URL`, direct to Postgres) pre-deploy.

## Testing

```ts
import { describe, expect, test } from 'bun:test'
test('adds', () => { expect(1 + 1).toBe(2) })
```

`bun test`, `bunx astro check`. React islands: `@testing-library/react` + `happy-dom`. `.astro` components: Playwright.

## Deployment: Cloudflare Workers

`@astrojs/cloudflare` emits a Worker into `dist/`; `wrangler deploy` ships it. Self-hosted Postgres is reached through **Hyperdrive** (connection pooler + query cache); sessions and rate-limit state live in **KV**.

```toml
# wrangler.toml
name = "my-site"
main = "./dist/_worker.js/index.js"   # emitted by @astrojs/cloudflare
compatibility_date = "2025-01-01"
compatibility_flags = ["nodejs_compat"]

[assets]
directory = "./dist"

[[hyperdrive]]
binding = "HYPERDRIVE"
id = "<id from `wrangler hyperdrive create`>"

[[kv_namespaces]]
binding = "KV"
id = "<id from `wrangler kv namespace create`>"

[vars]
PUBLIC_ORIGIN = "https://my-site.example.com"
# Secrets (never here): wrangler secret put BETTER_AUTH_SECRET / RESEND_API_KEY / SENTRY_DSN
```

Setup:

1. `bunx astro add cloudflare` (adapter) + `bun add -d wrangler`.
2. Provision Hyperdrive + KV (see Setup); put the ids in `wrangler.toml`.
3. Secrets: `wrangler secret put BETTER_AUTH_SECRET` (`openssl rand -base64 32`), `RESEND_API_KEY`, `SENTRY_DSN` (also needs `SENTRY_AUTH_TOKEN` at build for sourcemaps).
4. If migrations: `bunx drizzle-kit migrate` against `DATABASE_URL` (direct, not Hyperdrive).
5. `bunx wrangler deploy` (or push to `main` — see CI). Add a custom domain in the Cloudflare dashboard.

Pure-static sites (no SSR/Actions/DB) can skip the adapter and serve `dist/` from Cloudflare Pages / static assets instead.

## Gotchas

- **Bindings are request-time only** — read Hyperdrive/KV/secrets from `Astro.locals.runtime.env` (pages) or `ctx.locals.runtime.env` (Actions, middleware), never module scope. Build the DB client + Better Auth per request.
- **`nodejs_compat` required** for `postgres.js` (Node `net` polyfill). Set `compatibility_flags = ["nodejs_compat"]`, compatibility date ≥ 2024-09-23.
- **Hyperdrive vs migrations**: runtime reads `env.HYPERDRIVE.connectionString`; `drizzle-kit` migrations connect to `DATABASE_URL` directly.
- **KV is eventually consistent** and read-cached (~60s): fine for sessions/cache and approximate rate limits, wrong for atomic counters or immediate read-after-write — use a Durable Object there.
- **Tailwind v4**: `@tailwindcss/vite`, not the deprecated `@astrojs/tailwind`. Tokens in CSS `@theme`.
- **Content config location**: `src/content.config.ts` (Astro 5+); the legacy `src/content/config.ts` is silently ignored.
- **Content Layer loaders**: `glob({ pattern, base })` — `type: 'content'` is gone.
- **Actions vs API routes**: prefer Actions for typed RPC. API routes only for webhooks, OAuth callbacks, RSS, sitemap.
- **`prerender` default is `static`** — Astro prerenders by default; set `export const prerender = false` on pages that need the Worker (or `output: 'server'` to flip the default).
- **Postgres driver**: `postgres-js`, never `pg`.
- **Better Auth tables** are generated — don't hand-edit. Regenerate (`bunx @better-auth/cli generate`) + new migration after upgrades. Hashing is Web Crypto (scrypt) — no `bcrypt`/`argon2`.
- **Env**: build-time public via `import.meta.env.PUBLIC_*`; runtime secrets via `runtime.env`. `process.env` only works in `astro.config.mjs` (build) or under `nodejs_compat`.
- **React only when needed**: every island ships JS. Toggles via vanilla `<script>` in `.astro` are fine.
- **Silent hydration mismatch**: a React component in `.astro` without `client:*` renders static, no warning. Always add a directive.
- **MDX custom components**: pass via `components={{ ... }}` on `<Content />` — not auto-imported.
- **Bun lockfile** is `bun.lock`. Commit it.
- **Middleware runs only on SSR**: prerendered pages skip it — set static headers in Cloudflare response rules.
- **Sentry sourcemaps need `SENTRY_AUTH_TOKEN` at build time**, not just runtime — otherwise minified stack traces.
- **Resend sender**: `EMAIL_FROM` must be on a verified domain — Better Auth flows fail silently otherwise.
- **`console.log` banned** in SSR / Actions / middleware. Build scripts and `.astro` frontmatter are exempt. Inspect Workers logs with `wrangler tail`.

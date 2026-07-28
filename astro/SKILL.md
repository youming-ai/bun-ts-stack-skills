---
name: astro
description: All-in-Cloudflare TypeScript conventions for content-driven sites on Bun + Astro, deployed to Cloudflare Workers. Canonical stack — Bun (dev tooling), Astro 6, Content Collections, MDX, React islands, Astro Actions, Drizzle + Cloudflare D1 (optional), R2, KV, Better Auth (optional), Cloudflare Email Sending, Tailwind v4, shadcn/ui, Zod, Pagefind, Vitest, wrangler. Use whenever the user is scaffolding, writing, configuring, or deploying a content-driven site mentioning ANY of these — including "blog", "docs site", "marketing site", "landing page", "portfolio", "content collection", "MDX", "Astro action", "RSS feed", "sitemap", "send emails", "CI pipeline", "deploy to Cloudflare", "Workers", "D1", "R2", or Astro in a Bun + TS context. Trigger even when only one technology is mentioned. Scope is content-driven sites — pages, articles, SEO — including the light dynamic parts (comments, likes, signups) that Astro Actions cover.
---

# Astro on Cloudflare

Conventions for content-driven sites (blogs, docs, marketing, portfolios) on Bun + Astro, running entirely on Cloudflare. Use it when SEO and pages are the deliverable. Source of truth for stack choices, layout, integrations, and deploy. Deviate only with explicit reason.

**Everything is a Cloudflare binding.** One Worker, one `wrangler deploy`.

## Stack

| Layer        | Choice                                                                  |
| ------------ | ----------------------------------------------------------------------- |
| Dev runtime  | Bun (package manager, scripts)                                          |
| Prod runtime | Cloudflare Workers for SSR/Actions; static assets for pure-static sites |
| Language     | TypeScript (strict)                                                     |
| Framework    | Astro 6 (one major behind current)                                       |
| Content      | Content Collections (`glob()` loader) + MDX                             |
| Server       | Astro Actions (typed, Zod-validated)                                    |
| Interactive  | React islands (`@astrojs/react`) — only when needed                     |
| ORM          | Drizzle + Drizzle Kit (optional)                                        |
| Database     | Cloudflare D1 (optional)                                                |
| KV           | Cloudflare KV — session cache, auth rate limits (optional)              |
| Auth         | Better Auth (optional)                                                  |
| Email        | Cloudflare Email Sending (`send_email` binding)                         |
| CSS          | Tailwind v4 (`@tailwindcss/vite`)                                       |
| UI           | shadcn/ui (React islands) + lucide-react                                |
| Validation   | Zod                                                                     |
| SEO          | `@astrojs/sitemap` + `@astrojs/rss` + `<SEO>` component                 |
| Search       | Pagefind (static, build-time index)                                     |
| Logs         | Workers Observability (`console` + Workers Logs)                        |
| Test         | Vitest + `@cloudflare/vitest-pool-workers`                              |
| Deploy       | `bunx wrangler deploy`                                                  |

### Non-negotiables

- Bun is the dev runtime: package manager and script runner. Never `npm` / `pnpm` / `yarn` / `node`. (Tests run in workerd via Vitest, not in Bun.)
- SSR pages, Actions, and middleware run on **Cloudflare Workers** via `@astrojs/cloudflare`. Web-standard APIs only. Pure-static sites skip the adapter and deploy assets.
- **Zero JS by default**: Astro renders static HTML; interactive bits are explicit islands with `client:*`. If `.astro` can do it, don't reach for React.
- **Bindings are request-time** — read them from `locals.runtime.env`, never module scope.
- TypeScript `strict: true`.
- Do not install: `dotenv`, `ts-node`, `tsx`, `nodemon`, `jest`, `bcrypt`, `argon2`, `nodemailer`, `winston`, `bunyan`, `pino`, `@astrojs/tailwind` (deprecated), `@astrojs/node`.
- **Version policy**: stay one major behind current Astro. Current is 7.x, so pin `astro@^6` with `@astrojs/cloudflare@^13` (its peer range is `astro ^6.3`). Let `bunx astro add` resolve the other integrations — their majors move with Astro's.
- Vitest is the test runner, always through `@cloudflare/vitest-pool-workers` so tests get real bindings. Not `bun test`, not `jest`.

### Deliberately unconfigured

No formatter/linter, no git hooks, no CI pipeline — deferred, not rejected. When that day comes: Biome for lint/format, lefthook for hooks, GitHub Actions running `bunx astro check` + `bunx vitest run` + `bunx wrangler deploy`.

### When to add what

Nothing below is in the base install. Add one when the condition is actually hit.

| Need                                       | Add                                               |
| ------------------------------------------ | ------------------------------------------------- |
| Pure static blog / docs / marketing        | nothing extra; no Workers adapter required        |
| Comments, likes, newsletter signup         | `@astrojs/react` + Astro Actions                  |
| Persisted data                             | Drizzle + D1                                      |
| Login / sessions                           | Better Auth + KV                                  |
| User uploads / large media                 | R2 binding — serve via a route handler, no S3 SDK |
| Site search                                | Pagefind                                          |
| >10 GB of data or Postgres-only SQL        | Hyperdrive + Postgres + `drizzle-orm/postgres-js` |
| Marketing email, templates, campaigns      | Resend + React Email                              |
| Error alerting beyond Workers Logs         | `@sentry/astro`                                   |
| Rate limits outside Better Auth            | Cloudflare `ratelimits` binding                   |

## Architecture

```
                      Build time                     Request time
                      ──────────                     ────────────

  Content Collections ─► prerender ─► HTML ───────►  Cloudflare CDN  ──►  Browser
  (default)                                            (no Worker run)

  Pages (SSR)  ──────────────────────────────────►  Cloudflare Worker
  export const prerender = false                          │
                                                    @astrojs/cloudflare
                                                          │
                                                    stream HTML  ────────►  Browser
                                                          ▲
  Form / island ──► Astro Action ──POST /_actions/*►      │
                                                    ┌─────┴─────┬──────┐
                                                    ▼           ▼      ▼
                                                 D1 (DB)      KV    EMAIL
                                                    ▲
                                              Drizzle / Better Auth
```

Most pages **prerender** to static HTML and serve from the CDN with no Worker run. A pure-static site can skip `@astrojs/cloudflare` entirely and deploy the built assets. Routes with `export const prerender = false` run on Workers. Actions always run server-side. Bindings come from `locals.runtime.env` at request time — never module scope.

## Project structure

```
src/
├── pages/
│   ├── index.astro
│   ├── blog/{index,[...slug]}.astro
│   ├── rss.xml.ts
│   └── 404.astro
├── content/{blog,docs}/         # Content Collections sources
├── content.config.ts            # collections + Zod schemas
├── actions/index.ts             # Astro Actions
├── middleware.ts                # security headers
├── layouts/                     # BaseLayout, PostLayout, ...
├── components/
│   ├── *.astro                  # default — no JS
│   ├── ui/                      # shadcn/ui (React islands)
│   └── react/                   # custom React islands
├── lib/
│   ├── db.ts                    # Drizzle client (if DB)
│   ├── auth.ts                  # Better Auth (if auth)
│   └── email.ts                 # send_email binding wrapper
├── db/schema.ts                 # Drizzle schema (if DB)
├── schemas/
└── styles/global.css            # @import "tailwindcss"
public/{favicon.svg,robots.txt,og/}
drizzle/                         # generated migrations (= wrangler migrations_dir)
astro.config.mjs, vitest.config.ts, wrangler.toml
```

## Setup

```bash
bun create astro@latest my-site -- --template minimal   # then pin astro@^6 (see Version policy)

# Core
bunx astro add tailwind
bunx astro add mdx sitemap
bun add @astrojs/rss zod

# Interactivity (only when needed)
bunx astro add react
bunx shadcn@latest init

# Server runtime — only when SSR, Actions, DB, or auth need Workers
bunx astro add cloudflare
bun add -d wrangler

# Test
bun add -d vitest @cloudflare/vitest-pool-workers

# Optional
bun add drizzle-orm better-auth && bun add -d drizzle-kit   # DB + auth
bun add -d pagefind                                          # search

# Cloudflare resources — each command prints an id for wrangler.toml
bunx wrangler d1 create my-site
bunx wrangler kv namespace create KV
bunx wrangler email sending enable example.com   # onboard the sending domain
bunx wrangler types                              # regenerate Env after any config edit
```

## Integration patterns

### Content Collections

Schema is the source of truth for frontmatter — Astro validates at build time and generates types. Config lives at `src/content.config.ts`; loaders are `glob({ pattern, base })`.

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

Project conventions: every collection carries a `draft` flag and listings filter it out; `entry.id` is the slug; `render(entry)` returns `Content`. Standard `getCollection` / `getStaticPaths` usage otherwise.

### Astro Actions

Prefer Actions over API routes — Zod validation, typed RPC, progressive HTML forms, all free. Bindings arrive via `ctx.locals.runtime.env`.

```ts
// src/actions/index.ts
import { ActionError, defineAction } from 'astro:actions'
import { z } from 'astro:schema'
import { createDb } from '~/lib/db'

export const server = {
  subscribe: defineAction({
    accept: 'form',
    input: z.object({ email: z.email() }),
    handler: async ({ email }) => ({ ok: true as const }),
  }),
  like: defineAction({
    input: z.object({ postId: z.string() }),
    handler: async ({ postId }, ctx) => {
      if (!ctx.locals.user) throw new ActionError({ code: 'UNAUTHORIZED' })
      const db = createDb(ctx.locals.runtime.env.DB)
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

`.astro` by default; React only when interactive. Every island ships JS, so the directive is a budget decision: `client:idle` is the default choice, `client:load` only above the fold, `client:visible` below it, `client:only` when the dep can't SSR.

### Tailwind v4 + Cloudflare adapter

```ts
// astro.config.mjs
import cloudflare from '@astrojs/cloudflare'
import mdx from '@astrojs/mdx'
import react from '@astrojs/react'
import sitemap from '@astrojs/sitemap'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'astro/config'

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

### Drizzle over D1 (optional)

D1 is a binding, not a connection string — no pool, no driver, no `DATABASE_URL`.

```ts
// src/lib/db.ts
import { drizzle } from 'drizzle-orm/d1'
import * as schema from '~/db/schema'

// Pass locals.runtime.env.DB — bindings are request-scoped, never module scope.
export const createDb = (d1: D1Database) => drizzle(d1, { schema })
export type DB = ReturnType<typeof createDb>
```

```ts
// src/db/schema.ts — SQLite tables, not pg
import { integer, sqliteTable, text } from 'drizzle-orm/sqlite-core'

export const likes = sqliteTable('likes', {
  postId: text('post_id').primaryKey(),
  count: integer('count').notNull().default(0),
})
```

```ts
// drizzle.config.ts
import { defineConfig } from 'drizzle-kit'

export default defineConfig({
  schema: ['./src/db/schema.ts', './src/db/auth-schema.ts'],
  out: './drizzle',
  dialect: 'sqlite',
  // `generate` only emits SQL — no connection needed.
  // drizzle-kit studio against remote D1 additionally needs driver: 'd1-http' + dbCredentials.
})
```

`drizzle-kit generate` writes SQL into `drizzle/`; `wrangler d1 migrations apply my-site --local|--remote` runs it. Never `drizzle-kit migrate` — it has no D1 binding.

#### If you outgrow D1 and switch to Postgres

Postgres on Workers **must** go through Hyperdrive — an isolate can't hold a long-lived TCP connection across requests, and Hyperdrive pools them at the edge.

```ts
// src/lib/db.ts
import { drizzle } from 'drizzle-orm/postgres-js'
import postgres from 'postgres'
import * as schema from '~/db/schema'

// Pass locals.runtime.env.HYPERDRIVE.connectionString
export const createDb = (connStr: string) =>
  drizzle(postgres(connStr, { prepare: false, max: 5 }), { schema })
```

1. `bunx wrangler hyperdrive create my-site-db --connection-string="postgres://..."`, then a `[[hyperdrive]]` block in `wrangler.toml` (drop `[[d1_databases]]`).
2. Schema moves from `drizzle-orm/sqlite-core` to `pg-core`; Better Auth adapter goes `provider: 'sqlite'` → `'pg'`.
3. Keep `nodejs_compat` — postgres.js needs the Node `net` polyfill.
4. Migrations connect **directly** to Postgres via `DATABASE_URL` (`drizzle-kit migrate`), not through Hyperdrive and not via `wrangler d1 migrations apply`. Hyperdrive is not a migration endpoint.

For SSR/Actions with several DB round trips, consider Smart Placement — but not on pure-static or asset-heavy sites.

### Better Auth + KV (optional)

Request-scoped like the DB. KV keeps session reads off D1's single-region primary and backs Better Auth's built-in rate limiter.

```ts
// src/lib/auth.ts
import { betterAuth } from 'better-auth'
import { drizzleAdapter } from 'better-auth/adapters/drizzle'
import { createDb } from '~/lib/db'
import { sendEmail } from '~/lib/email'

// env is the bindings object (`locals.runtime.env`)
export function createAuth(env: Env) {
  return betterAuth({
    database: drizzleAdapter(createDb(env.DB), { provider: 'sqlite' }),
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
        sendEmail(env, user.email, 'Reset your password', `<a href="${url}">Reset your password</a>`),
    },
    emailVerification: {
      sendVerificationEmail: ({ user, url }) =>
        sendEmail(env, user.email, 'Verify your email', `<a href="${url}">Verify your email</a>`),
    },
  })
}
```

```ts
// src/pages/api/auth/[...all].ts
import type { APIRoute } from 'astro'
import { createAuth } from '~/lib/auth'

export const prerender = false
export const ALL: APIRoute = ({ request, locals }) =>
  createAuth(locals.runtime.env).handler(request)
```

Session: `createAuth(Astro.locals.runtime.env).api.getSession({ headers: Astro.request.headers })`. Re-run `bunx @better-auth/cli generate --output src/db/auth-schema.ts` + `bunx drizzle-kit generate` after every Better Auth or plugin change — plugins add tables.

### Email (Cloudflare Email Sending)

No API key, no SDK — the `send_email` binding is the whole integration.

```ts
// src/lib/email.ts
export async function sendEmail(env: Env, to: string, subject: string, html: string) {
  await env.EMAIL.send({
    to,
    from: { email: env.EMAIL_FROM, name: env.SITE_NAME },
    subject,
    html,
    text: html.replace(/<[^>]+>/g, ' ').trim(), // clients that only show plain text
  })
}
```

From an Action:

```ts
contact: defineAction({
  accept: 'form',
  input: z.object({ email: z.email(), message: z.string().min(1).max(2000) }),
  handler: async ({ email, message }, ctx) => {
    await sendEmail(ctx.locals.runtime.env, 'team@example.com', `Contact from ${email}`, `<p>${message}</p>`)
    return { ok: true as const }
  },
}),
```

The `from` domain must be onboarded first: `bunx wrangler email sending enable example.com`. Transactional only — marketing sends belong on a marketing platform.

### R2 (optional)

Not in the base stack. Add it when there are actual uploads — `bunx wrangler r2 bucket create my-site`, then:

```toml
[[r2_buckets]]
binding = "R2"
bucket_name = "my-site"
```

It is a binding like the rest, so serve through a route handler and never add an S3 SDK:

```ts
// src/pages/api/files/[key].ts
import type { APIRoute } from 'astro'

export const prerender = false
export const GET: APIRoute = async ({ params, locals }) => {
  const obj = await locals.runtime.env.R2.get(params.key!)
  if (!obj) return new Response('Not found', { status: 404 })
  return new Response(obj.body, {
    headers: { 'content-type': obj.httpMetadata?.contentType ?? 'application/octet-stream' },
  })
}
```

Authorize writes. For large or direct-from-browser uploads, put the bucket behind a custom domain instead of streaming through the Worker.

### Security middleware

`src/middleware.ts` runs on every server-rendered request. Headers only — Better Auth handles its own rate limiting.

```ts
// src/middleware.ts
import { defineMiddleware } from 'astro:middleware'

export const onRequest = defineMiddleware(async (_ctx, next) => {
  const res = await next()
  res.headers.set('X-Frame-Options', 'DENY')
  res.headers.set('X-Content-Type-Options', 'nosniff')
  res.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin')
  res.headers.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()')
  res.headers.set('Content-Security-Policy',
    "default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline'; script-src 'self'")
  return res
})
```

Tighten CSP if you use `is:inline` or third-party widgets. **Prerendered pages skip middleware** — set headers for those in Cloudflare's response header rules. If you need a limiter outside Better Auth, use the `ratelimits` binding (`env.LIMITER.limit({ key })`), keyed on `cf-connecting-ip`.

### SEO + RSS + Sitemap

Sitemap is automatic once `@astrojs/sitemap` is installed and `site` is set in `astro.config.mjs` — forgetting `site` silently produces no sitemap and breaks canonical URLs.

`src/pages/rss.xml.ts` uses `@astrojs/rss`'s `rss()` over `getCollection('blog')`, same draft filter as the listings. Meta tags go in one `<SEO>` component reading frontmatter — title, description, canonical, OG, Twitter — used by every layout rather than hand-written per page.

### Pagefind (optional)

Build-time static index over the built HTML — no server, no API key. Chain it into the build script (`"build": "astro build && pagefind --site dist"`), then mount `PagefindUI` from `/pagefind/pagefind-ui.js` in a `<script>`. Runs on the output, so it indexes prerendered pages only.

## Configuration

### TypeScript

`tsconfig.json` extends `astro/tsconfigs/strict`, adds alias `"~/*": ["./src/*"]` + `"verbatimModuleSyntax": true`. Binding types come from the generated `worker-configuration.d.ts` (`bunx wrangler types`) — do not hand-write `Env`.

### Environment variables

| Scope                | Convention       | Access                                                                                       |
| -------------------- | ---------------- | -------------------------------------------------------------------------------------------- |
| Public (client-safe) | `PUBLIC_` prefix | `import.meta.env.PUBLIC_FOO`                                                                 |
| Server secrets       | Worker binding   | `Astro.locals.runtime.env.FOO` (pages) / `ctx.locals.runtime.env.FOO` (Actions, middleware)  |

Secrets (`BETTER_AUTH_SECRET`, OAuth client secrets) go in with `wrangler secret put NAME`, never in `wrangler.toml` or the client bundle. Re-run `bunx wrangler types` after editing `wrangler.toml`.

## Testing

Vitest through `@cloudflare/vitest-pool-workers` — real D1/KV bindings instead of mocks.

```ts
// vitest.config.ts
import { defineWorkersConfig } from '@cloudflare/vitest-pool-workers/config'

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: './wrangler.toml' },
        miniflare: { compatibilityFlags: ['nodejs_compat'] },
      },
    },
  },
})
```

```ts
// src/db/likes.test.ts
import { env } from 'cloudflare:test'
import { expect, test } from 'vitest'
import { createDb } from '~/lib/db'
import { likes } from './schema'

test('records a like', async () => {
  const db = createDb(env.DB)
  await db.insert(likes).values({ postId: 'p1', count: 1 })
  expect(await db.select().from(likes)).toHaveLength(1)
})
```

`bunx vitest` (watch) / `bunx vitest run` (once). Apply migrations to the local D1 first (`wrangler d1 migrations apply my-site --local`). Never mock the ORM.

Content Collections, `.astro` rendering, and island hydration aren't covered by the Workers pool — `bunx astro check` for types, Playwright for the rendered page. React islands in isolation: `@testing-library/react` + `happy-dom` in a separate non-Workers Vitest project.

Add `@cloudflare/vitest-pool-workers` to `tsconfig.json` `types` so `cloudflare:test` resolves.

## Deploy

`@astrojs/cloudflare` emits a Worker into `dist/`; `wrangler deploy` ships it. Pure-static sites (no SSR/Actions/DB/auth) should skip the adapter and deploy `dist/` as static assets instead.

```toml
# wrangler.toml
name = "my-site"
main = "./dist/_worker.js/index.js"   # emitted by @astrojs/cloudflare
compatibility_date = "2025-07-01"
compatibility_flags = ["nodejs_compat"]

[observability]
enabled = true

[assets]
directory = "./dist"

# Only the bindings the site actually uses:

[[d1_databases]]
binding = "DB"
database_name = "my-site"
database_id = "<id from `wrangler d1 create`>"
migrations_dir = "drizzle"

[[kv_namespaces]]
binding = "KV"
id = "<id from `wrangler kv namespace create`>"

[[send_email]]
name = "EMAIL"

[vars]
PUBLIC_ORIGIN = "https://my-site.example.com"
EMAIL_FROM = "hello@example.com"
SITE_NAME = "My Site"
# Secrets (never here): wrangler secret put BETTER_AUTH_SECRET / ...
```

No CI pipeline — deploy manually from a clean checkout:

```bash
bunx astro check && bunx vitest run     # the checks CI would have run
bun run build
bunx wrangler d1 migrations apply my-site --remote   # only if the site has a DB
bunx wrangler deploy
```

Secrets are one-time: `wrangler secret put BETTER_AUTH_SECRET` (`openssl rand -base64 32`). Custom domain goes in the Cloudflare dashboard. Building also catches MDX / Content Collection schema mismatches, and `astro check` is the only place `.astro` gets type-checked.

## Gotchas

- **D1 is SQLite**: no `jsonb`, no `uuid` type, integer timestamps. Use `drizzle-orm/sqlite-core`, not `pg-core`.
- **D1 limits**: 10 GB per database, 1 MB per query result, single-region primary. Past those, switch to Hyperdrive + Postgres.
- **KV is eventually consistent** and read-cached (~60s): fine for session acceleration, wrong for immediate global revocation or atomic counters — use D1 or a Durable Object there.
- **Astro 6 ships Zod 4**: `z.string().email()` → `z.email()`, same for `.url()` / `.uuid()`. Applies to `astro:schema` in Actions and to collection schemas.
- **Astro 6 needs Node ≥ 22.12** for the build (the deployed Worker is unaffected).
- **Adapter major is coupled to Astro major**: `astro@6` ↔ `@astrojs/cloudflare@13`. Bumping one alone breaks the peer range.
- **Content Layer is the only API in Astro 6**: `glob({ pattern, base })`, config at `src/content.config.ts` (the legacy `src/content/config.ts` was removed, not deprecated), `type: 'content'` is gone.
- **Actions vs API routes**: prefer Actions for typed RPC. API routes only for webhooks, OAuth callbacks, RSS, sitemap, file serving.
- **`prerender` default is `static`** — set `export const prerender = false` on pages that need the Worker (or `output: 'server'` to flip the default).
- **Better Auth on Workers** hashes via Web Crypto (scrypt) — `bcrypt`/`argon2` don't run there anyway.
- **React only when needed**: every island ships JS. Toggles via vanilla `<script>` in `.astro` are fine.
- **Silent hydration mismatch**: a React component in `.astro` without `client:*` renders static, no warning. Always add a directive.
- **MDX custom components**: pass via `components={{ ... }}` on `<Content />` — not auto-imported.
- **Bun lockfile** is `bun.lock`. Commit it.
- **Logging is `console`** with an object payload, captured by Workers Logs when `observability.enabled` is on. Inspect live with `wrangler tail`, or query in the Workers Observability dashboard. No log library.
- **`@cloudflare/vitest-pool-workers` pins its Vitest major** (peer `vitest ^4.1`). Bump the two together.

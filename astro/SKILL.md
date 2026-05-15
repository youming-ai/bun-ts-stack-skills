---
name: astro
description: Full-stack TypeScript conventions for content-driven sites built on Bun + Astro. Canonical stack — Bun, Astro 5, Content Collections, MDX, React islands, Astro Actions, Drizzle (optional), Better Auth (optional), Tailwind v4, shadcn/ui, Zod, Resend, pino, Sentry, lefthook, GitHub Actions, Biome, bun test, Dokploy. Use whenever the user is scaffolding, writing, configuring, or deploying a content-driven site mentioning ANY of these — including "blog", "docs site", "marketing site", "landing page", "portfolio", "content collection", "MDX", "Astro action", "RSS feed", "sitemap", "send emails", "add logging", "CI pipeline", or Astro in a Bun + TS context. Trigger even when only one technology is mentioned. This is the content-site counterpart to `tanstack`, which covers app-driven projects.
---

# Astro Bun Stack

Conventions for content-driven sites (blogs, docs, marketing, portfolios) on Bun + Astro. Counterpart to `tanstack` — pick this when SEO and pages matter; pick `tanstack` when state and login matter.

## Stack

| Layer       | Choice                                                        |
| ----------- | ------------------------------------------------------------- |
| Runtime     | Bun                                                           |
| Language    | TypeScript (strict)                                           |
| Framework   | Astro 5 (LTS)                                                 |
| Content     | Content Collections (`glob()` loader) + MDX                   |
| Server      | Astro Actions (typed, Zod-validated)                          |
| Interactive | React islands (`@astrojs/react`) — only when needed           |
| ORM         | Drizzle + Drizzle Kit (optional)                              |
| Database    | PostgreSQL via `postgres` (optional)                          |
| Auth        | Better Auth (optional)                                        |
| CSS         | Tailwind v4 (`@tailwindcss/vite`)                             |
| UI          | shadcn/ui (React islands) + lucide-react                      |
| Validation  | Zod                                                           |
| SEO         | `@astrojs/sitemap` + `@astrojs/rss` + `<SEO>` component       |
| Search      | Pagefind (static, build-time index)                           |
| Email       | Resend + React Email (only if site sends mail)                |
| Logging     | pino (in `src/middleware.ts`)                                 |
| Monitoring  | Sentry (`@sentry/astro`)                                      |
| Security    | Astro middleware: security headers + rate limit               |
| Lint/Format | Biome                                                         |
| Git hooks   | lefthook                                                      |
| Test        | `bun test`                                                    |
| CI          | GitHub Actions                                                |
| Deploy      | Dokploy on VPS (Docker) with `@astrojs/node` adapter          |

### Non-negotiables

- Bun is runtime, package manager, test runner, script runner. Never `npm` / `pnpm` / `yarn` / `node`.
- TypeScript `strict: true`.
- **Zero JS by default**: Astro renders static HTML; interactive bits are explicit islands with `client:*`. If `.astro` can do it, don't reach for React.
- Do not install: `dotenv`, `ts-node`, `tsx`, `nodemon`, `jest`, `vitest`, `bcrypt`, `argon2`, `pg`, `eslint`, `prettier`, `nodemailer`, `husky`, `pre-commit`, `winston`, `bunyan`, `@astrojs/tailwind` (deprecated).

### When to add what

| Need                                      | Add                                            |
| ----------------------------------------- | ---------------------------------------------- |
| Pure static blog / docs / marketing       | nothing extra                                  |
| Comments, likes, newsletter signup        | `@astrojs/react` + Astro Actions               |
| Persisted data                            | Drizzle + Postgres                             |
| Login                                     | Better Auth                                    |
| Site search                               | Pagefind                                       |

## Architecture

```
                       Build time                       Runtime
                       ──────────                       ───────

  src/content/  ───►  Content Collections  ───►  static HTML
  (.md, .mdx)         (Zod-validated)            (prerendered)
                                                          │
  src/pages/    ───►  .astro pages         ─────────────► │
                                                          │
  src/actions/  ───►  Astro Actions  ──────────────────►  /_actions/*
                      (Zod-validated)          (server-rendered routes
                                                only when called)
                              │
                              ▼
                    Drizzle (optional) ───► PostgreSQL
                    Better Auth (optional)
```

Most pages **prerender** to static HTML. Routes with `export const prerender = false` (or `output: 'server'`) run on the server. Actions always run server-side.

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
├── middleware.ts                # security headers + pino + rate limit
├── layouts/                     # BaseLayout, PostLayout, ...
├── components/
│   ├── *.astro                  # default — no JS
│   ├── ui/                      # shadcn/ui (React islands)
│   └── react/                   # custom React islands
├── lib/
│   ├── db.ts                    # Drizzle (if DB)
│   ├── auth.ts                  # Better Auth (if auth)
│   ├── email.ts                 # Resend (if mail)
│   └── logger.ts                # pino
├── emails/                      # React Email templates
├── db/schema.ts                 # Drizzle schema (if DB)
├── schemas/
└── styles/global.css            # @import "tailwindcss"
public/{favicon.svg,robots.txt,og/}
.github/workflows/ci.yml
astro.config.mjs, biome.json, lefthook.yml, Dockerfile
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

# Server (Actions, SSR, deploy)
bunx astro add node

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

Prefer Actions over API routes — Zod validation, typed RPC, progressive HTML forms, all free.

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

### Tailwind v4 + shadcn/ui

```ts
// astro.config.mjs
import { defineConfig } from 'astro/config'
import tailwindcss from '@tailwindcss/vite'
import mdx from '@astrojs/mdx'
import sitemap from '@astrojs/sitemap'
import react from '@astrojs/react'
import node from '@astrojs/node'

export default defineConfig({
  site: 'https://example.com',
  integrations: [mdx(), sitemap(), react()],
  adapter: node({ mode: 'standalone' }),
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

### Drizzle + Postgres (optional)

```ts
// src/lib/db.ts
import { drizzle } from 'drizzle-orm/postgres-js'
import postgres from 'postgres'
import * as schema from '~/db/schema'

const client = postgres(import.meta.env.DATABASE_URL, { prepare: false })
export const db = drizzle(client, { schema })
```

Always `import.meta.env.*`, never `process.env.*` in Astro code.

### Better Auth (optional)

```ts
// src/pages/api/auth/[...all].ts
import { auth } from '~/lib/auth'
import type { APIRoute } from 'astro'

export const prerender = false
export const ALL: APIRoute = ({ request }) => auth.handler(request)
```

Session: `await auth.api.getSession({ headers: Astro.request.headers })`. Wire `sendResetPassword` and `sendVerificationEmail` to Resend (below) — flows fail silently otherwise. Re-run the CLI after every upgrade.

### Email (Resend + React Email)

Only when the site sends mail.

```ts
// src/lib/email.ts
import { Resend } from 'resend'
import type { ReactElement } from 'react'

const resend = new Resend(import.meta.env.RESEND_API_KEY)

export async function sendEmail(opts: { to: string; subject: string; react: ReactElement }) {
  const { error } = await resend.emails.send({ from: import.meta.env.EMAIL_FROM, ...opts })
  if (error) throw new Error(`email send failed: ${error.message}`)
}
```

From an Action:

```ts
contact: defineAction({
  accept: 'form',
  input: z.object({ email: z.string().email(), message: z.string().min(1).max(2000) }),
  handler: async ({ email, message }) => {
    await sendEmail({ to: 'team@example.com', subject: `Contact from ${email}`, react: ContactEmail({ email, message }) })
    return { ok: true as const }
  },
}),
```

Env: `RESEND_API_KEY`, `EMAIL_FROM` (verified Resend sender).

### Logging (pino)

`console.log` is fine in build scripts; in SSR / Actions / middleware, use pino.

```ts
// src/lib/logger.ts
import pino from 'pino'

export const logger = pino({
  level: import.meta.env.LOG_LEVEL ?? 'info',
  transport: import.meta.env.DEV ? { target: 'pino-pretty' } : undefined,
})
```

Mounted in middleware below.

### Error monitoring (Sentry)

`bunx astro add @sentry/astro` wires client + server.

```ts
// astro.config.mjs
import sentry from '@sentry/astro'

export default defineConfig({
  integrations: [
    sentry({
      dsn: import.meta.env.SENTRY_DSN,
      environment: import.meta.env.MODE,
      sourceMapsUploadOptions: { project: 'my-site', authToken: process.env.SENTRY_AUTH_TOKEN },
    }),
    // ...
  ],
})
```

Errors in Actions and SSR pages are captured automatically.

### Security middleware

`src/middleware.ts` runs on every server-rendered request (prerendered pages skip it). Security headers, request logging, and a basic rate limit on auth/Actions.

```ts
// src/middleware.ts
import { defineMiddleware } from 'astro:middleware'
import { logger } from '~/lib/logger'

const hits = new Map<string, { count: number; reset: number }>()
function rateLimit(key: string, limit = 20, windowMs = 15 * 60 * 1000) {
  const now = Date.now()
  const slot = hits.get(key)
  if (!slot || slot.reset < now) {
    hits.set(key, { count: 1, reset: now + windowMs })
    return true
  }
  slot.count += 1
  return slot.count <= limit
}

export const onRequest = defineMiddleware(async (ctx, next) => {
  const start = performance.now()
  const ip = ctx.request.headers.get('x-forwarded-for')?.split(',')[0].trim() ?? 'anon'

  if (ctx.url.pathname.startsWith('/api/auth') || ctx.url.pathname.startsWith('/_actions/')) {
    if (!rateLimit(`${ip}:${ctx.url.pathname}`)) return new Response('Too many requests', { status: 429 })
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

In-memory `Map` is fine for one Dokploy instance — scale horizontally → Redis. Tighten CSP if you use `is:inline` or third-party widgets.

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

`tsconfig.json` extends `astro/tsconfigs/strict` and adds alias `"~/*": ["./src/*"]` + `"verbatimModuleSyntax": true`.

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
```

`astro check` is the only place `.astro` gets type-checked. Building catches MDX / Content Collection schema mismatches.

## Testing

```ts
import { describe, expect, test } from 'bun:test'
test('adds', () => { expect(1 + 1).toBe(2) })
```

`bun test`, `bunx astro check`. React islands: `@testing-library/react` + `happy-dom`. `.astro` components: Playwright.

## Deployment: Dokploy

Self-hosted Docker on a VPS. `@astrojs/node` in `standalone` mode for SSR; pure-static sites can skip Dokploy and use Cloudflare Pages.

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
ENV HOST=0.0.0.0
ENV PORT=3000
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./
EXPOSE 3000
CMD ["bun", "run", "./dist/server/entry.mjs"]
```

For pure-static output: serve `dist/` with Caddy/Nginx instead.

Setup:

1. Install Dokploy: `curl -sSL https://dokploy.com/install.sh | sh`
2. Application → repo → build type **Dockerfile**.
3. If DB: add a Postgres service. Copy the internal connection string.
4. Env vars:
   - `SITE_URL` — public origin (also `site` in `astro.config.mjs`)
   - `DATABASE_URL` (if DB) — internal hostname, never `localhost`
   - `BETTER_AUTH_SECRET` / `BETTER_AUTH_URL` (if auth)
   - `RESEND_API_KEY`, `EMAIL_FROM` (if mail) — verified Resend sender
   - `SENTRY_DSN`, `SENTRY_AUTH_TOKEN` — runtime + sourcemap upload (build-time)
   - `LOG_LEVEL`
5. Enable HTTPS (Traefik + Let's Encrypt).
6. Enable auto-deploy on Git push.
7. If migrations: `bunx drizzle-kit migrate` pre-deploy.

## Gotchas

- **Tailwind v4**: `@tailwindcss/vite`, not the deprecated `@astrojs/tailwind`. Tokens in CSS `@theme`.
- **Content config location**: `src/content.config.ts` (Astro 5+); the legacy `src/content/config.ts` is silently ignored.
- **Content Layer loaders**: `glob({ pattern, base })` — `type: 'content'` is gone.
- **Actions vs API routes**: prefer Actions for typed RPC. API routes only for webhooks, OAuth callbacks, RSS, sitemap.
- **`prerender` defaults to `false`** with the Node adapter — set `export const prerender = true` per page (or `output: 'static'`).
- **Postgres driver**: `postgres-js`, never `pg`.
- **Better Auth tables** are generated — don't hand-edit. Regenerate + new migration after upgrades.
- **`import.meta.env`** in Astro, never `process.env.*`.
- **React only when needed**: every island ships JS. Toggles via vanilla `<script>` in `.astro` are fine.
- **Silent hydration mismatch**: a React component in `.astro` without `client:*` renders static, no warning. Always add a directive.
- **MDX custom components**: pass via `components={{ ... }}` on `<Content />` — not auto-imported.
- **Bun lockfile** is `bun.lock`. Commit it.
- **Cloudflare adapter**: works, but Better Auth and `postgres` assume long-lived connections. Node + VPS is the easy path.
- **Middleware runs only on SSR**: prerendered pages skip it — set static headers in the reverse proxy.
- **In-memory rate limit doesn't survive scaling**: one Dokploy instance is fine; otherwise Redis.
- **Sentry sourcemaps need `SENTRY_AUTH_TOKEN` at build time**, not just runtime — otherwise minified stack traces.
- **Resend sender**: `EMAIL_FROM` must be on a verified domain — Better Auth flows fail silently otherwise.
- **`console.log` banned** in SSR / Actions / middleware. Build scripts and `.astro` frontmatter are exempt.
- **CSP and inline scripts**: Astro `<script>` blocks compile to bundles (`script-src 'self'` works). `is:inline` or third-party widgets need policy adjustments.

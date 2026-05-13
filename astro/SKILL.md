---
name: astro-bun-stack
description: Full-stack TypeScript conventions for content-driven sites built on Bun + Astro. Canonical stack — Bun, Astro 6, Content Collections, MDX, React islands, Astro Actions, Drizzle (optional), Better Auth (optional), Tailwind v4, shadcn/ui, Zod, Biome, bun test, Dokploy. Use whenever the user is scaffolding, writing, configuring, or deploying a content-driven site mentioning ANY of these — including "blog", "docs site", "marketing site", "landing page", "portfolio", "content collection", "MDX", "Astro action", "RSS feed", "sitemap", or Astro in a Bun + TS context. Trigger even when only one technology is mentioned. This is the content-site counterpart to `tanstack-bun-stack`, which covers app-driven projects.
---

# Astro Bun Stack

Project conventions for content-driven sites (blogs, docs, marketing, portfolios) built on Bun + Astro. Treat this as the source of truth for stack choices, project layout, integration patterns, and deployment. Deviate only with explicit reason.

This is the **content-site** counterpart to `tanstack-bun-stack`. Use this when the project is primarily about pages, articles, and SEO; use `tanstack-bun-stack` when the project is primarily an interactive app behind login.

## Stack

| Layer       | Choice                                                        |
| ----------- | ------------------------------------------------------------- |
| Runtime     | Bun                                                           |
| Language    | TypeScript (strict)                                           |
| Framework   | Astro 6                                                       |
| Content     | Content Collections (`glob()` loader) + MDX                   |
| Server      | Astro Actions (typed server functions, Zod-validated)         |
| Interactive | React islands (`@astrojs/react`) — only where needed          |
| ORM         | Drizzle + Drizzle Kit (optional, only if DB is needed)        |
| Database    | PostgreSQL via `postgres` (optional)                          |
| Auth        | Better Auth (optional, only if auth is needed)                |
| CSS         | Tailwind v4 (`@tailwindcss/vite`)                             |
| UI          | shadcn/ui (React islands) + lucide-react                      |
| Validation  | Zod                                                           |
| SEO         | `@astrojs/sitemap` + `@astrojs/rss` + `<SEO>` component       |
| Search      | Pagefind (static, build-time index)                           |
| Lint/Format | Biome                                                         |
| Test        | `bun test`                                                    |
| Deploy      | Dokploy on VPS (Docker) with `@astrojs/node` adapter          |

### Non-negotiables

- Bun is the runtime, package manager, test runner, and script runner. Never reach for `npm` / `pnpm` / `yarn` / `node`.
- All code is TypeScript with `strict: true`.
- **Zero JS by default**: Astro renders static HTML; interactive bits are explicit islands with `client:*` directives. If a feature can be done with an `.astro` component, do not reach for React.
- No Node-only dependencies that break in Bun.
- Prefer Bun built-ins: `Bun.password`, `Bun.file`, native `fetch`, `bun:test`, `bun --watch`.
- Do **not** install: `dotenv`, `ts-node`, `tsx`, `nodemon`, `jest`, `vitest`, `bcrypt`, `argon2`, `pg`, `eslint`, `prettier`, the deprecated `@astrojs/tailwind` integration.

### When to add what

This stack scales from a pure static blog to a content site with light dynamic features. Add layers only as you need them:

| Need                                      | Add                                            |
| ----------------------------------------- | ---------------------------------------------- |
| Pure static blog / docs / marketing       | nothing extra — stop at the core               |
| Comments, likes, newsletter signup        | `@astrojs/react` + Astro Actions               |
| Persisted data                            | Drizzle + Postgres                             |
| Login                                     | Better Auth                                    |
| Site search                               | Pagefind (post-build step)                     |

## Architecture

```
                       Build time                       Runtime
                       ──────────                       ───────

  src/content/  ───►  Content Collections  ───►  static HTML pages
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

Key idea: most pages are **prerendered** to static HTML at build time. Only routes that opt into `export const prerender = false` (or all of them, if you set `output: 'server'`) run on the server. Actions are always server-side, regardless of page mode.

## Project structure

```
src/
├── pages/                        # File-based routing
│   ├── index.astro
│   ├── blog/
│   │   ├── index.astro           # listing
│   │   └── [...slug].astro       # post page
│   ├── rss.xml.ts                # RSS feed
│   └── 404.astro
├── content/                      # Content Collections sources
│   ├── blog/
│   │   ├── hello-world.md
│   │   └── another-post.mdx
│   └── docs/
├── content.config.ts             # Collections + Zod schemas (Astro 5+ location)
├── actions/
│   └── index.ts                  # Astro Actions, exported under `server`
├── layouts/
│   ├── BaseLayout.astro
│   └── PostLayout.astro
├── components/
│   ├── *.astro                   # default — no JS
│   ├── ui/                       # shadcn/ui (React, used as islands)
│   └── react/                    # custom React islands
├── lib/
│   ├── db.ts                     # Drizzle client (if DB used)
│   └── auth.ts                   # Better Auth config (if auth used)
├── db/
│   └── schema.ts                 # Drizzle schema (if DB used)
├── schemas/                      # shared Zod schemas
└── styles/
    └── global.css                # Tailwind v4 entry: @import "tailwindcss"
public/
├── favicon.svg
├── robots.txt
└── og/                           # OG images
astro.config.mjs
biome.json
Dockerfile
```

## Setup commands

```bash
# 1. Scaffold
bun create astro@latest my-site
cd my-site

# 2. Tailwind v4 (Astro 5.2+ wires the Vite plugin automatically)
bunx astro add tailwind

# 3. MDX + Sitemap + RSS
bunx astro add mdx
bunx astro add sitemap
bun add @astrojs/rss

# 4. React (only if interactive islands are needed)
bunx astro add react

# 5. Node adapter (for server features and Dokploy deploy)
bunx astro add node

# 6. shadcn/ui (only after React is added)
bunx shadcn@latest init

# 7. Biome
bun add -d @biomejs/biome
bunx biome init

# 8. Validation
bun add zod

# 9. Optional: DB + Auth
bun add drizzle-orm postgres better-auth
bun add -d drizzle-kit

# 10. Pagefind (optional, post-build search)
bun add -d pagefind
```

## Integration patterns

### Content Collections

Define one schema per collection in `src/content.config.ts`. The schema is the source of truth for frontmatter — Astro validates at build time and generates types.

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

Query content in pages:

```astro
---
// src/pages/blog/index.astro
import { getCollection } from 'astro:content'
import BaseLayout from '~/layouts/BaseLayout.astro'

const posts = (await getCollection('blog', ({ data }) => !data.draft))
  .sort((a, b) => b.data.pubDate.valueOf() - a.data.pubDate.valueOf())
---
<BaseLayout title="Blog">
  <ul>
    {posts.map((p) => (
      <li>
        <a href={`/blog/${p.id}`}>{p.data.title}</a>
        <time datetime={p.data.pubDate.toISOString()}>
          {p.data.pubDate.toLocaleDateString()}
        </time>
      </li>
    ))}
  </ul>
</BaseLayout>
```

Render a single post with `[...slug].astro`:

```astro
---
import { getCollection, render } from 'astro:content'
import PostLayout from '~/layouts/PostLayout.astro'

export async function getStaticPaths() {
  const posts = await getCollection('blog', ({ data }) => !data.draft)
  return posts.map((post) => ({ params: { slug: post.id }, props: { post } }))
}

const { post } = Astro.props
const { Content } = await render(post)
---
<PostLayout frontmatter={post.data}>
  <Content />
</PostLayout>
```

### Astro Actions (typed server functions)

Use Actions instead of API routes whenever possible. They give you Zod validation, type-safe RPC, and progressive enhancement for HTML forms — all for free.

```ts
// src/actions/index.ts
import { defineAction, ActionError } from 'astro:actions'
import { z } from 'astro:schema'

export const server = {
  subscribe: defineAction({
    accept: 'form',
    input: z.object({
      email: z.string().email(),
    }),
    handler: async ({ email }) => {
      // call email service, write to DB, etc.
      return { ok: true as const }
    },
  }),

  like: defineAction({
    input: z.object({ postId: z.string() }),
    handler: async ({ postId }, ctx) => {
      // ctx is Astro's request context
      if (!ctx.locals.user) {
        throw new ActionError({ code: 'UNAUTHORIZED' })
      }
      // increment likes...
      return { likes: 42 }
    },
  }),
}
```

Call from a React island:

```tsx
import { actions } from 'astro:actions'

export function LikeButton({ postId }: { postId: string }) {
  return (
    <button
      onClick={async () => {
        const { data, error } = await actions.like({ postId })
        if (error) console.error(error.code)
        else console.log(data.likes)
      }}
    >
      Like
    </button>
  )
}
```

Call from an HTML form (works without JS):

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

React components are imported into `.astro` files and given a hydration directive:

```astro
---
import { LikeButton } from '~/components/react/LikeButton'
---
<LikeButton postId={post.id} client:idle />
```

Directive matrix:

| Directive        | When to use                                           |
| ---------------- | ----------------------------------------------------- |
| `client:load`    | Critical interactivity above the fold                 |
| `client:idle`    | Default for most islands; hydrates after page load    |
| `client:visible` | Below-the-fold widgets                                |
| `client:only`    | Components that cannot SSR (browser-only deps)        |

Use `.astro` components by default; reach for React only when needed.

### Tailwind v4 + shadcn/ui

`astro.config.mjs`:

```ts
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

`src/styles/global.css`:

```css
@import "tailwindcss";
@plugin "@tailwindcss/typography";

@theme {
  --color-brand: oklch(0.7 0.18 250);
  --font-display: "Inter", sans-serif;
}

@custom-variant dark (&:where(.dark, .dark *));
```

There is **no `tailwind.config.js`** in v4. Tokens live in `@theme`. Imported once from a layout:

```astro
---
// src/layouts/BaseLayout.astro
import '~/styles/global.css'
---
```

For shadcn/ui: install only after `@astrojs/react` is added. Components are imported into `.astro` files and given a `client:*` directive at the usage site.

### Drizzle + Postgres (optional)

Same pattern as `tanstack-bun-stack`: `postgres-js` driver, never `pg`.

```ts
// src/lib/db.ts
import { drizzle } from 'drizzle-orm/postgres-js'
import postgres from 'postgres'
import * as schema from '~/db/schema'

const client = postgres(import.meta.env.DATABASE_URL, { prepare: false })
export const db = drizzle(client, { schema })
```

Use `import.meta.env.*` in Astro, not `process.env.*` directly.

### Better Auth (optional)

If the site needs login, wire Better Auth into a catch-all API route:

```ts
// src/pages/api/auth/[...all].ts
import { auth } from '~/lib/auth'
import type { APIRoute } from 'astro'

export const prerender = false
export const ALL: APIRoute = ({ request }) => auth.handler(request)
```

Read session in Actions or pages via `auth.api.getSession({ headers: Astro.request.headers })`. Re-run `bunx @better-auth/cli generate` after every upgrade.

### SEO + RSS + Sitemap

**Sitemap** is automatic once `@astrojs/sitemap` is added and `site` is set in config.

**RSS** is one route:

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

**Meta tags**: keep a small `<SEO>` component in `components/` that renders title, description, canonical, OG and Twitter cards. Drive it from frontmatter.

### Pagefind search (optional)

Pagefind builds a static search index from your built HTML. Add a post-build step:

```json
{
  "scripts": {
    "build": "astro build && pagefind --site dist"
  }
}
```

Then mount the UI in a layout:

```astro
<link rel="stylesheet" href="/pagefind/pagefind-ui.css" />
<div id="search"></div>
<script>
  import('/pagefind/pagefind-ui.js').then(({ PagefindUI }) => {
    new PagefindUI({ element: '#search' })
  })
</script>
```

## Configuration

### TypeScript

`tsconfig.json` extends `astro/tsconfigs/strict` and adds:

- Path alias `"~/*": ["./src/*"]`
- `"verbatimModuleSyntax": true`

### Biome

`biome.json`:

```json
{
  "$schema": "https://biomejs.dev/schemas/2.0.0/schema.json",
  "files": {
    "ignoreUnknown": true,
    "includes": ["**", "!**/dist/**", "!**/.astro/**", "!**/node_modules/**"]
  },
  "formatter": { "indentStyle": "space", "indentWidth": 2, "lineWidth": 100 },
  "linter": { "enabled": true, "rules": { "recommended": true } },
  "javascript": { "formatter": { "quoteStyle": "single", "semicolons": "asNeeded" } }
}
```

`.astro` files are not yet first-class in Biome; format their `<script>` and `<style>` blocks manually or with the Prettier Astro plugin if you must. The bulk of your `.ts` and `.tsx` files are covered.

Commands:

```bash
bunx biome check --write
bunx astro check         # type-check .astro files
```

## Testing

```ts
// src/lib/foo.test.ts
import { describe, expect, test } from 'bun:test'

describe('foo', () => {
  test('adds', () => {
    expect(1 + 1).toBe(2)
  })
})
```

```bash
bun test
bun test --watch
bunx astro check         # also part of CI
```

For component tests on React islands, use `@testing-library/react` with `happy-dom`. For `.astro` components, integration-test via `astro:experimental` test API or Playwright.

## Deployment: Dokploy on VPS

Same shape as `tanstack-bun-stack`: self-hosted, Docker-based, no vendor lock-in. The Astro side needs the `@astrojs/node` adapter in `standalone` mode.

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
ENV HOST=0.0.0.0
ENV PORT=3000
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./
EXPOSE 3000
CMD ["bun", "run", "./dist/server/entry.mjs"]
```

For **pure static** output (no Actions, no SSR), simplify the runtime stage to serve `dist/` with Caddy or Nginx instead. Or skip Dokploy entirely and put the static build on Cloudflare Pages.

### Dokploy steps

1. Install Dokploy on the VPS:
   ```bash
   curl -sSL https://dokploy.com/install.sh | sh
   ```
2. Create an Application, point at the Git repo, build type **Dockerfile**.
3. If using DB: add a Postgres service in Dokploy, copy the internal connection string.
4. Environment variables:
   - `DATABASE_URL` (if DB) — internal hostname, not `localhost`
   - `BETTER_AUTH_SECRET` (if auth) — `openssl rand -base64 32`
   - `BETTER_AUTH_URL` (if auth) — public origin
   - `SITE_URL` — public origin, also set as `site` in `astro.config.mjs`
5. Enable HTTPS via the built-in Traefik + Let's Encrypt.
6. Enable auto-deploy on Git push.

If migrations are needed, run `bunx drizzle-kit migrate` as a Dokploy pre-deploy step.

## Gotchas

- **Tailwind v4**: use `@tailwindcss/vite`, not the deprecated `@astrojs/tailwind`. No JS config; tokens live in CSS `@theme`. Only use the v4-compatible shadcn components.
- **Content config location**: it's `src/content.config.ts` (Astro 5+), not `src/content/config.ts`. The old path is silently ignored.
- **Content Layer loaders**: use `glob({ pattern, base })` from `astro/loaders` — the legacy `type: 'content'` syntax is gone.
- **Astro Actions vs API routes**: prefer Actions for typed server functions. Use API routes only for webhooks, OAuth callbacks, RSS, sitemap, and other non-RPC endpoints.
- **`prerender` flag**: by default with the Node adapter, pages are SSR. Set `export const prerender = true` per page (or use `output: 'static'`) for static HTML. Most pages on a content site should prerender.
- **Postgres driver**: `postgres` (postgres.js), never `pg`. Adapter is `drizzle-orm/postgres-js`.
- **Better Auth tables** are CLI-generated; don't hand-edit. Regenerate after upgrades and create a new migration.
- **`import.meta.env` vs `process.env`**: in Astro code, use `import.meta.env.*`. `process.env` works only on the server and is not type-safe.
- **React only when needed**: every React island ships JS. Use `.astro` for anything non-interactive — server data, static markup, even simple toggles via vanilla `<script>` in the .astro file.
- **Hydration directive mismatch**: a component imported into an `.astro` file but used without `client:*` will render as static HTML with no interactivity, silently. The compiler does not warn.
- **MDX components**: when using custom components inside MDX, pass them via the `components={{ ... }}` prop on `<Content />`. They are not auto-imported.
- **Bun lockfile** is `bun.lock`. Commit it.
- **Cloudflare adapter**: works, but Better Auth and `postgres` assume long-lived connections — pure edge deployments may need adjustments. Node adapter on VPS is the path of least resistance.

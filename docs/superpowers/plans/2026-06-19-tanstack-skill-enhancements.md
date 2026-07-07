# tanstack/SKILL.md Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 4 new sections to `tanstack/SKILL.md` — rendering strategy, environment variables, AI tooling conventions, and Cloudflare Workers alternative deployment.

> **Status:** Historical implementation plan. Superseded by the 2026-07-06 move to Cloudflare Workers + KV + Hyperdrive as the primary shared foundation for both `tanstack` and `astro`. Current behavior lives in `README.md`, `tanstack/SKILL.md`, and `astro/SKILL.md`.

**Architecture:** Single-file edit to `tanstack/SKILL.md`. Insertions are done bottom-to-top to avoid line-number drift. Each task inserts one section, verifies it reads correctly, and commits.

**Tech Stack:** Markdown editing only. No code, no tests, no dependencies.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `tanstack/SKILL.md` | Modify | All 4 new sections |
| `docs/superpowers/specs/2026-06-19-tanstack-skill-enhancements-design.md` | Already exists | Design spec (reference only) |

No new files created. No other files modified.

---

### Task 1: Insert Alternative: Cloudflare Workers (Deployment section)

**Files:**
- Modify: `tanstack/SKILL.md` — insert after Dokploy section, before Gotchas

**Anchor text to find:** The line `7. Pre-deploy: \`bunx drizzle-kit migrate\`.` followed by a blank line, followed by `## Gotchas`.

- [ ] **Step 1: Insert CF Workers section**

Using Edit, find the anchor and insert the new section between the Dokploy content and Gotchas:

old_string:
```
7. Pre-deploy: `bunx drizzle-kit migrate`.

## Gotchas
```

new_string:
```
7. Pre-deploy: `bunx drizzle-kit migrate`.

### Alternative: Cloudflare Workers

For scale-to-zero, edge latency, and no VPS management. This path deviates
from the non-negotiables above — to take it, make the following swaps.
All other tools (Resend, Sentry, Tailwind, Biome, lefthook, GitHub Actions)
work as-is.

| Default (VPS) | Swap to | Why |
|---|---|---|
| `postgres` driver | `@neondatabase/serverless` (HTTP) | Workers can't hold long-lived TCP |
| Better Auth | Clerk, Auth0, or Supabase Auth | Better Auth assumes Node + long-lived DB |
| Drizzle + postgres-js | Drizzle + `drizzle-orm/neon-http` | Same ORM, HTTP adapter |
| Dokploy + Docker | `wrangler deploy` | Workers builds from source |
| `process.env.X` | `c.env.X` (Hono) / server function request | Workers bindings, not Node process |

**Setup**:

```bash
bun create tsrouter-app@latest my-app && cd my-app
bun add @neondatabase/serverless drizzle-orm
bun add -d wrangler
# Auth: use Clerk or edge-compatible provider
```

**Wrangler config** (`wrangler.toml`):

```toml
[vars]
PUBLIC_ORIGIN = "https://my-app.example.com"
# Secrets: `wrangler secret put DATABASE_URL` (not in toml)
```

**Env access**:

```ts
// Hono handler — use c.env (Workers bindings object)
app.use('*', cors({ origin: c.env.PUBLIC_ORIGIN, credentials: true }))
```

Note: TanStack Start server functions don't expose `c.env` directly.
Use one of: (a) Hono middleware that injects env into context, (b) `process.env`
with Wrangler `--compatibility-flags nodejs_compat`, or (c) a small Hono wrapper
that calls the server function. The simplest path is to keep server logic in
Hono handlers where `c.env` is available natively.

**Gotchas**:
- No long-lived connections: every request = new HTTP round-trip
- Cold start: ~50–100ms first request; subsequent are fast
- CPU time limit: 30s (free) / 5min (paid)
- `process.env` does not exist on Workers — always use `c.env` or bindings
- No Node built-ins (`fs`, `child_process`, `crypto` partial) — use Workers equivalents

## Gotchas
```

- [ ] **Step 2: Verify insertion**

Run: `grep -n "Alternative: Cloudflare Workers" tanstack/SKILL.md`
Expected: one match, line number > 400

Run: `grep -n "## Gotchas" tanstack/SKILL.md`
Expected: one match, line number after the new section

- [ ] **Step 3: Commit**

```bash
git add tanstack/SKILL.md
git commit -m "feat(tanstack): add Cloudflare Workers alternative deployment section"
```

---

### Task 2: Insert For AI tooling (Configuration section)

**Files:**
- Modify: `tanstack/SKILL.md` — insert after GitHub Actions subsection, before Testing

**Anchor text to find:** The line `` Add a `services: postgres:` block if tests touch the DB. `` followed by a blank line, followed by `## Testing`.

- [ ] **Step 1: Insert AI tooling section**

old_string:
```
Add a `services: postgres:` block if tests touch the DB.

## Testing
```

new_string:
```
Add a `services: postgres:` block if tests touch the DB.

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
- `process.env.X` for server-only, `import.meta.env.VITE_X` for public
- Loaders handle data fetching; never use `getServerSideProps` or `getStaticProps`
- TanStack's built-in CSRF middleware (`createCsrfMiddleware`) protects server functions by default; add it explicitly if you define `src/start.ts`

## Testing
```

- [ ] **Step 2: Verify insertion**

Run: `grep -n "### For AI tooling" tanstack/SKILL.md`
Expected: one match

Run: `grep -n "## Testing" tanstack/SKILL.md`
Expected: one match, after the new section

- [ ] **Step 3: Commit**

```bash
git add tanstack/SKILL.md
git commit -m "feat(tanstack): add AI tooling conventions section"
```

---

### Task 3: Insert Environment variables (Configuration section)

**Files:**
- Modify: `tanstack/SKILL.md` — insert after TypeScript subsection, before lefthook

**Anchor text to find:** The line `` `tsconfig.json`: `strict`, `moduleResolution: "bundler"`, `verbatimModuleSyntax: true`, alias `"~/*": ["./src/*"]`. `` followed by a blank line, followed by `### lefthook`.

- [ ] **Step 1: Insert env vars section**

old_string:
```
`tsconfig.json`: `strict`, `moduleResolution: "bundler"`, `verbatimModuleSyntax: true`, alias `"~/*": ["./src/*"]`.

### lefthook
```

new_string:
```
`tsconfig.json`: `strict`, `moduleResolution: "bundler"`, `verbatimModuleSyntax: true`, alias `"~/*": ["./src/*"]`.

### Environment variables

| Scope | Convention | Access |
|---|---|---|
| Public (client-safe) | `VITE_` prefix | `import.meta.env.VITE_FOO` |
| Server-only | no prefix | `process.env.FOO` |

Never expose `DATABASE_URL`, `BETTER_AUTH_SECRET`, or other server-only values
to client bundles. The build strips non-`VITE_` variables automatically.

### lefthook
```

- [ ] **Step 2: Verify insertion**

Run: `grep -n "### Environment variables" tanstack/SKILL.md`
Expected: one match

Run: `grep -n "### lefthook" tanstack/SKILL.md`
Expected: one match, after the new section

- [ ] **Step 3: Commit**

```bash
git add tanstack/SKILL.md
git commit -m "feat(tanstack): add environment variables convention section"
```

---

### Task 4: Insert Rendering strategy (Architecture section)

**Files:**
- Modify: `tanstack/SKILL.md` — insert after Architecture section content, before Project structure

**Anchor text to find:** The line `- One **Zod schema** per concept in \`src/schemas/\`, shared by Hono / Form / Drizzle.` followed by a blank line, followed by `## Project structure`.

- [ ] **Step 1: Insert rendering strategy section**

old_string:
```
- One **Zod schema** per concept in `src/schemas/`, shared by Hono / Form / Drizzle.

## Project structure
```

new_string:
```
- One **Zod schema** per concept in `src/schemas/`, shared by Hono / Form / Drizzle.

### Rendering strategy

TanStack Start supports per-route rendering:

| Route type | Mode | How |
|---|---|---|
| Data-independent (landing, blog, about) | Static (SSG) | `export const prerender = true` |
| Per-request data (dashboard, account) | Server (SSR) | default |
| Purely client-rendered (SPA fallback) | CSR | `export const ssr = false` |

Server functions can also be cached at build time for static generation — see
[TanStack docs on Static Server Functions](https://tanstack.com/start/latest/docs/framework/react/guides/static-server-functions).

## Project structure
```

- [ ] **Step 2: Verify insertion**

Run: `grep -n "### Rendering strategy" tanstack/SKILL.md`
Expected: one match

Run: `grep -n "## Project structure" tanstack/SKILL.md`
Expected: one match, after the new section

- [ ] **Step 3: Commit**

```bash
git add tanstack/SKILL.md
git commit -m "feat(tanstack): add rendering strategy section"
```

---

### Task 5: Final verification

**Files:**
- Read: `tanstack/SKILL.md` (full file)

- [ ] **Step 1: Read full file and verify structure**

Read `tanstack/SKILL.md` and verify:
- 4 new sections present: Rendering strategy, Environment variables, For AI tooling, Alternative: Cloudflare Workers
- No existing content was deleted or corrupted
- All sections are in the correct order within their parent sections
- The file is valid markdown (no broken tables, no unclosed code blocks)

Expected structure after all edits:
```
## Architecture
  ### Rendering strategy          ← NEW
## Project structure
## Setup
## Integration patterns
## Configuration
  ### Tailwind v4
  ### Biome
  ### TypeScript
  ### Environment variables       ← NEW
  ### lefthook
  ### GitHub Actions
  ### For AI tooling              ← NEW
## Testing
## Deployment: Dokploy
  ### Alternative: Cloudflare Workers  ← NEW
## Gotchas
```

- [ ] **Step 2: Final commit (if any fixes needed)**

If any issues found in Step 1, fix them and commit:
```bash
git add tanstack/SKILL.md
git commit -m "fix(tanstack): correct formatting in new sections"
```

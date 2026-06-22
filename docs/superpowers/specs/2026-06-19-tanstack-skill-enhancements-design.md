# Design: tanstack/SKILL.md Enhancements

**Date**: 2026-06-19
**Source**: Lessons from Lovable's TanStack Start blog post + TanStack official docs
**Scope**: `tanstack/SKILL.md` only; `astro/SKILL.md` unchanged

## Context

Lovable published a post detailing their migration to TanStack Start. Three practices stood out as directly applicable to the existing `tanstack` skill:

1. Per-route prerender strategy (SSG/SSR/CSR per route)
2. AI-friendly file naming conventions (official TanStack: `*.functions.ts`, `*.server.ts`, `*.ts`)
3. `VITE_` prefix convention for public env vars (Vite underneath TanStack Start)

Additionally, adding a **Cloudflare Workers alternative** deployment path was identified as valuable, though it conflicts with the current skill's "no edge runtimes" stance.

During research, a **CSRF middleware gap** was also found: TanStack Start provides `createCsrfMiddleware` but the current skill doesn't mention it.

## Design Decision: Strict Default + Explicit Alternative

- `Non-negotiables` section stays unchanged
- CF Workers section explicitly states "this path deviates from the non-negotiables"
- All other tools remain as-is for both paths

---

## Changes

### 1. Rendering strategy (Architecture section)

**Insert after**: Architecture diagram (current line ~62)
**Insert before**: "Most pages prerender..." paragraph (current line ~75)

```markdown
### Rendering strategy

TanStack Start supports per-route rendering:

| Route type | Mode | How |
|---|---|---|
| Data-independent (landing, blog, about) | Static (SSG) | `export const prerender = true` |
| Per-request data (dashboard, account) | Server (SSR) | default |
| Purely client-rendered (SPA fallback) | CSR | `export const ssr = false` |

Server functions can also be cached at build time for static generation — see
[TanStack docs on Static Server Functions](https://tanstack.com/start/latest/docs/framework/react/guides/static-server-functions).
```

**Rationale**: Lovable's article says AI auto-applies `prerender = true` when a route qualifies. This section teaches the AI when to use each mode.

---

### 2. Environment variables (Configuration section)

**Insert after**: TypeScript subsection (current line ~369)
**Insert before**: Biome subsection

```markdown
### Environment variables

| Scope | Convention | Access |
|---|---|---|
| Public (client-safe) | `VITE_` prefix | `import.meta.env.VITE_FOO` |
| Server-only | no prefix | `process.env.FOO` |

Never expose `DATABASE_URL`, `BETTER_AUTH_SECRET`, or other server-only values
to client bundles. The build strips non-`VITE_` variables automatically.
```

**Rationale**: Lovable calls this the key security boundary. Current skill uses `process.env.PUBLIC_ORIGIN!` (server-side only, fine), but doesn't explain the `VITE_` convention. This gives AI a clear rule for client vs server env.

---

### 3. For AI tooling (Configuration section, before Gotchas)

**Insert after**: GitHub Actions subsection
**Insert before**: Gotchas

```markdown
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
```

**Rationale**: File naming comes from official TanStack docs (verified). Co-location matches Lovable's "one file, one mental model" philosophy. The CSRF note addresses a security gap found during research.

---

### 4. Alternative: Cloudflare Workers (Deployment section)

**Insert after**: Dokploy section
**Insert before**: Gotchas

```markdown
## Alternative: Cloudflare Workers

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
\`\`\`bash
bun create tsrouter-app@latest my-app && cd my-app
bun add @neondatabase/serverless drizzle-orm
bun add -d wrangler
# Auth: use Clerk or edge-compatible provider
\`\`\`

**Wrangler config** (`wrangler.toml`):
\`\`\`toml
[vars]
PUBLIC_ORIGIN = "https://my-app.example.com"
# Secrets: `wrangler secret put DATABASE_URL` (not in toml)
\`\`\`

**Env access**:
\`\`\`ts
// Hono handler — use c.env (Workers bindings object)
app.use('*', cors({ origin: c.env.PUBLIC_ORIGIN, credentials: true }))

// Server function — use getRequest() and read from c.env
// Option: pass c.env into server function via middleware/context
// Option: use Workers env bindings directly in the handler
\`\`\`

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
```

**Rationale**: Pure swap recipe, doesn't touch main path. Auth options listed without locking to one. "Deviates from non-negotiables" framing maintains strict default.

---

## Out of Scope

- **`astro/SKILL.md`**: Not touched. These additions are TanStack Start-specific.
- **Shared foundation changes**: None. Both skills keep their current shared tools.
- **README.md**: No changes needed (install/build process unchanged).

## Open Questions for Implementation

1. Should the `build.sh` or `README.md` be updated to mention the new CF Workers alternative in the decision tree?
2. Should the Gotchas section get a new entry for the `createCsrfMiddleware` default behavior?

# bun-ts-stack-skills

A pair of [Claude skills](https://www.anthropic.com/news/skills) for full-stack TypeScript work on the **Bun** ecosystem, running entirely on **Cloudflare**. The two are siblings — identical foundation (runtime, deploy, data, auth), differing only in the top layer depending on whether the project is **app-driven** or **content-driven**.

Everything is a Cloudflare binding: D1 for data, KV for session cache, `send_email` for mail, R2 when there are files. No external database, no mail provider, no separate API server. One Worker, one `wrangler deploy`.

## The skills

| Skill                     | Use when the project is…                                                                                      |
| ------------------------- | ------------------------------------------------------------------------------------------------------------- |
| [`tanstack`](./tanstack/) | An app — SaaS, dashboard, internal tool, anything behind login with complex state. Top: TanStack Start.        |
| [`astro`](./astro/)       | A content site — blog, docs, marketing, portfolio, landing page. Top: Astro + Content Collections.             |

Install one, the other, or both. If a single project has both (e.g. an app at `app.example.com` and a marketing site at `example.com`), keep both — Claude picks the right one per task.

## Decision tree

```
Is the primary deliverable…
├── articles, docs, marketing pages, with SEO as a hard requirement?
│      → astro
└── an authenticated app with persistent state and complex interactions?
       → tanstack
```

Edge cases:

- **SaaS product docs** → `astro` (docs are content; the product is separate)
- **Dashboard + public marketing pages** → two sub-projects, one each
- **Blog with comments / likes / subscribe** → still `astro` — Astro Actions handle the light dynamic parts

## Shared foundation

Both skills share these defaults. In `astro`, DB/auth/Worker runtime pieces are optional when the site is pure static content.

| Layer        | Choice                                          |
| ------------ | ----------------------------------------------- |
| Dev runtime  | Bun (pkg manager, scripts)                      |
| Prod runtime | Cloudflare Workers (V8 isolate)                 |
| Language     | TypeScript (strict)                             |
| ORM          | Drizzle + Drizzle Kit                           |
| Database     | Cloudflare D1 (SQLite)                          |
| KV           | Cloudflare KV (session cache, auth rate limits) |
| Auth         | Better Auth                                     |
| Email        | Cloudflare Email Sending (`send_email` binding) |
| CSS          | Tailwind v4 (`@tailwindcss/vite`)               |
| UI           | shadcn/ui (Radix + Tailwind) + lucide-react     |
| Validation   | Zod                                             |
| Logs         | Workers Observability (`console` + Workers Logs)|
| Build        | Vite                                            |
| Test         | Vitest + `@cloudflare/vitest-pool-workers`      |
| Deploy       | `bunx wrangler deploy` (no CI pipeline)         |

They diverge only at the top layer: `tanstack` renders an app with TanStack Start; `astro` renders content with Astro + Content Collections. Everything below follows the same defaults, with `astro` allowed to omit Workers/DB/auth when the site is pure static.

Both skills forbid the same default tool drift: `npm`/`pnpm`/`yarn`/`node` as CLIs, `dotenv`, `ts-node`/`tsx`, `nodemon`, `jest`, `bcrypt`/`argon2`, `nodemailer`, `winston`/`bunyan`/`pino`, deprecated framework integrations.

### Version policy

Both frameworks stay **one major behind current**, so the ecosystem has caught up before we adopt. Astro is currently 7.x → pin `astro@^6` + `@astrojs/cloudflare@^13`. TanStack Start has only ever shipped `1.x`, so it pins the latest `1.x` until a `2.x` exists.

### Deliberately unconfigured

No formatter/linter, no git hooks, no CI pipeline — deferred, not rejected. Deploy is a manual `bunx wrangler deploy`. When these come back: Biome, lefthook, and GitHub Actions running typecheck + `vitest run` + deploy.

### Deliberately not in the default stack

Each skill has an "add only when the need is real" table. These are the escape hatches, all documented, none installed up front:

| Escape hatch                                | Condition                                                    |
| ------------------------------------------- | ------------------------------------------------------------ |
| Hyperdrive + PostgreSQL + `postgres` driver | >10 GB of data, or SQL D1 can't express                      |
| R2 binding                                  | Actual user uploads or large media                           |
| Resend + React Email                        | Marketing email — transactional stays on the binding          |
| Sentry                                      | Error alerting beyond Workers Logs                           |
| Hono                                        | Standalone API with many middleware layers or OpenAPI        |
| Durable Object                              | Strong consistency, atomic counters, realtime coordination   |
| `ratelimits` binding                        | Rate limits outside Better Auth's built-in limiter           |

When changing the shared foundation (e.g. switching ORM), update **both** SKILL.md files in the same commit — they stay in lockstep on the shared layer.

The two files overlap ~60% (D1, Better Auth, email, testing, gotchas). That is deliberate: each `.skill` is uploaded and loaded independently and cannot import the other, so a shared base file would break both. Don't try to DRY it — keep them in lockstep instead.

## Install

**Prebuilt** — download `tanstack.skill` / `astro.skill` from the [latest release](../../releases) and upload in Claude's skill settings.

**From source**:

```bash
git clone https://github.com/<your-handle>/bun-ts-stack-skills.git
cd bun-ts-stack-skills && ./build.sh
# → dist/tanstack.skill, dist/astro.skill
```

## Editing

Each skill is a single `SKILL.md` under its folder. Edit → `./build.sh` → re-upload. Validation rules (see [Anthropic's skill docs](https://docs.claude.com/en/docs/claude-code/skills)): YAML frontmatter with `name` + `description`, description ≤ 1024 chars.

## License

MIT — see [LICENSE](./LICENSE).

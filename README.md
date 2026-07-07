# bun-ts-stack-skills

A pair of [Claude skills](https://www.anthropic.com/news/skills) for full-stack TypeScript work on the **Bun** ecosystem, deployed to **Cloudflare Workers**. The two are siblings — identical foundation (runtime, deploy, data, auth), differing only in the top layer depending on whether the project is **app-driven** or **content-driven**.

## The skills

| Skill                       | Use when the project is…                                                                                             |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| [`tanstack`](./tanstack/)   | An app — SaaS, dashboard, internal tool, anything behind login with complex state. Top: TanStack Start + Hono.        |
| [`astro`](./astro/)         | A content site — blog, docs, marketing, portfolio, landing page. Top: Astro + Content Collections.                    |

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

| Layer       | Choice                                |
| ----------- | ------------------------------------- |
| Dev runtime | Bun (also pkg manager, test, scripts) |
| Prod runtime | Cloudflare Workers (V8 isolate)      |
| Language    | TypeScript (strict)                   |
| ORM         | Drizzle + Drizzle Kit                 |
| Database    | Self-hosted PostgreSQL via Cloudflare Hyperdrive |
| KV          | Cloudflare KV (session/cache acceleration, approximate rate-limit) |
| Auth        | Better Auth                           |
| CSS         | Tailwind v4 (`@tailwindcss/vite`)     |
| UI          | shadcn/ui + lucide-react              |
| Validation  | Zod                                   |
| Email       | Resend + React Email                  |
| Logging     | pino                                  |
| Monitoring  | Sentry                                |
| Lint/Format | Biome                                 |
| Git hooks   | lefthook                              |
| Test        | `bun test` by default; Cloudflare Vitest only for Workers integration |
| CI/CD       | GitHub Actions + `wrangler deploy`    |
| Deploy      | Cloudflare Workers                    |

They diverge only at the top layer: `tanstack` renders an app with TanStack Start + Hono; `astro` renders content with Astro + Content Collections. Everything below follows the same defaults, with `astro` allowed to omit Workers/DB/auth when the site is pure static.

Both skills forbid the same default tool drift: `npm`/`pnpm`/`yarn`/`node` as CLIs, `dotenv`, `ts-node`/`tsx`, `nodemon`, `jest`, `bcrypt`/`argon2`, `eslint`, `prettier`, `nodemailer`, `husky`/`pre-commit`, `winston`/`bunyan`, deprecated framework integrations. Two escape hatches are explicit: `vitest` is allowed only for Cloudflare Workers integration tests that need the real runtime/bindings, and `pg` is allowed only when library interop or an official Cloudflare path requires it.

When changing the shared foundation (e.g. switching ORM), update **both** SKILL.md files in the same commit — they stay in lockstep on the shared layer.

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

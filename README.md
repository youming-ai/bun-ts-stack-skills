# bun-ts-stack-skills

A pair of [Claude skills](https://www.anthropic.com/news/skills) that capture project conventions for full-stack TypeScript work on the **Bun + TypeScript** ecosystem.

The two skills are siblings — they share a foundation (Bun runtime, Drizzle, Better Auth, Tailwind v4, Biome, Dokploy) but differ on the top layer depending on whether the project is **app-driven** or **content-driven**.

## The skills

| Skill                                                | Use when the project is…                              |
| ---------------------------------------------------- | ----------------------------------------------------- |
| [`tanstack`](./tanstack/)        | An app — SaaS, dashboard, internal tool, anything behind login with complex state. Top layer: TanStack Start + Hono. |
| [`astro`](./astro/)              | A content site — blog, docs, marketing, portfolio, landing page. Top layer: Astro + Content Collections. |

Install one, the other, or both. If a single project has both (e.g. an app at `app.example.com` and a marketing site at `example.com`), keep both installed — Claude will pick the right one per task.

## Decision tree

```
Is the primary deliverable…
├── articles, docs, marketing pages, with SEO as a hard requirement?
│      → astro
└── an authenticated app with persistent state and complex interactions?
       → tanstack
```

Edge cases:

- **Documentation for a SaaS product** → `astro` (the docs are content; the product is separate)
- **Dashboard with public marketing pages** → run two sub-projects, one each
- **Blog with comments / likes / subscribe** → still `astro`. Astro Actions handle the light dynamic parts; you don't need a full app framework

## Shared foundation

Both skills assume:

| Layer       | Choice                                |
| ----------- | ------------------------------------- |
| Runtime     | Bun (also pkg manager, test, scripts) |
| Language    | TypeScript (strict)                   |
| ORM         | Drizzle + Drizzle Kit                 |
| Database    | PostgreSQL (`postgres` driver)        |
| Auth        | Better Auth                           |
| CSS         | Tailwind v4 (`@tailwindcss/vite`)     |
| UI          | shadcn/ui + lucide-react              |
| Validation  | Zod                                   |
| Lint/Format | Biome                                 |
| Test        | `bun test`                            |
| Deploy      | Dokploy on VPS (Docker)               |

Both skills forbid the same things: `npm`/`pnpm`/`yarn`/`node` as CLIs, `dotenv`, `ts-node`/`tsx`, `nodemon`, `jest`/`vitest`, `bcrypt`/`argon2`, `pg`, `eslint`, `prettier`, deprecated framework integrations.

When changing the shared foundation (e.g. switching ORM), update **both** SKILL.md files in the same commit. The skills are designed to stay in lockstep.

## Install

### Option 1 — Use the prebuilt `.skill` files

Download from the [latest release](../../releases):

- `tanstack.skill`
- `astro.skill`

Upload either or both in Claude's skill settings.

### Option 2 — Build from source

```bash
git clone https://github.com/<your-handle>/bun-ts-stack-skills.git
cd bun-ts-stack-skills
./build.sh
# → dist/tanstack.skill
# → dist/astro.skill
```

Then upload the `.skill` files in Claude.

## Editing the skills

Each skill is a single `SKILL.md` under its own folder. To edit:

1. Modify the relevant `SKILL.md`
2. Run `./build.sh` to rebuild the `.skill` packages
3. Re-upload to Claude

The skill-creator validation rules (see [Anthropic's skill docs](https://docs.claude.com/en/docs/claude-code/skills)) require:

- YAML frontmatter with `name` and `description`
- `description` ≤ 1024 characters
- Reasonable SKILL.md body (< 500 lines is ideal, both skills are within this)

## License

MIT — see [LICENSE](./LICENSE).

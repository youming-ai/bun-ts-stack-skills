# tanstack-bun-stack

A [Claude skill](https://www.anthropic.com/news/skills) that captures the project conventions for full-stack TypeScript apps built on **Bun + TanStack Start**.

When this skill is installed, Claude will follow these conventions for project scaffolding, integration patterns, configuration, and deployment — without having to be told them every time.

## The stack

| Layer       | Choice                            |
| ----------- | --------------------------------- |
| Runtime     | Bun                               |
| Language    | TypeScript (strict)               |
| Framework   | TanStack Start                    |
| Build       | Vite                              |
| API         | Hono                              |
| ORM         | Drizzle + Drizzle Kit             |
| Database    | PostgreSQL (driver: `postgres`)   |
| Auth        | Better Auth                       |
| CSS         | Tailwind v4 (`@tailwindcss/vite`) |
| UI          | shadcn/ui + lucide-react          |
| Forms       | TanStack Form                     |
| Validation  | Zod                               |
| Lint/Format | Biome                             |
| Test        | `bun test`                        |
| Deploy      | Dokploy on VPS (Docker)           |

## Install

### Option 1 — Use the prebuilt `.skill` file

Download `tanstack-bun-stack.skill` from the [latest release](../../releases) and upload it in Claude's skill settings.

### Option 2 — Build from source

```bash
git clone https://github.com/<your-handle>/tanstack-bun-stack.git
cd tanstack-bun-stack
zip -r tanstack-bun-stack.skill SKILL.md
```

Then upload the `.skill` file in Claude.

## What's inside `SKILL.md`

- **Stack** with non-negotiables (what to use, what not to install)
- **Architecture** diagram of how the pieces fit
- **Project structure** with the canonical `src/` layout
- **Setup commands** for scaffolding a new project end to end
- **Integration patterns** with copy-pasteable snippets for:
  - Mounting Hono inside TanStack Start
  - Drizzle with `postgres.js`
  - Better Auth + Drizzle + Hono
  - TanStack Form + Zod (shared schema)
- **Configuration** files for Tailwind v4, Biome, TypeScript
- **Testing** with `bun test`
- **Deployment** to Dokploy on a VPS, with a working Dockerfile
- **Gotchas** — the foot-guns that took real time to find

## License

MIT — see [LICENSE](./LICENSE).

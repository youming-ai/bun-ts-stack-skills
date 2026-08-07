# bun-ts-stack-skills

A Claude skill for full-stack TypeScript apps on **Bun + TanStack Start**, deployed to **Cloudflare Workers** — everything runs on Cloudflare bindings, no external services.

## Stack

| Layer | Choice |
| --- | --- |
| Framework | TanStack Start (React 19 + TanStack Router) |
| Database / cache | Cloudflare D1 / KV |
| Auth | Better Auth |
| Email | Cloudflare Email Sending |
| ORM / forms / validation | Drizzle / TanStack Form / Zod |
| CSS / UI | Tailwind v4 / shadcn-ui |
| Dev / test / deploy | Bun / Vitest / wrangler |

Full conventions live in [`tanstack/SKILL.md`](./tanstack/SKILL.md) — the single source of truth.

## Build & use

```bash
./build.sh   # → dist/tanstack.skill
```

Upload `dist/tanstack.skill` in Claude's skill settings. The skill auto-triggers on any project mentioning the stack.

## Develop

Edit `tanstack/SKILL.md` (keep the frontmatter `description` ≤ 1024 chars), re-run `./build.sh`, re-upload.

## License

MIT — see [LICENSE](./LICENSE).

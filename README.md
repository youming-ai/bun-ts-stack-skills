# bun-ts-stack-skills

A single [Claude skill](https://www.anthropic.com/news/skills) for full-stack TypeScript apps built with **Bun + TanStack Start** and deployed on **Cloudflare Workers**.

The canonical stack and conventions live in [`tanstack/SKILL.md`](./tanstack/SKILL.md): D1, KV, Better Auth, Email Sending, Tailwind, Drizzle, Vitest, and Wrangler.

## Structure

```text
tanstack/SKILL.md  # the skill source
build.sh           # builds dist/tanstack.skill
README.md          # this file
LICENSE
```

`dist/` is generated and ignored by git.

## Build

```bash
./build.sh
# → dist/tanstack.skill
```

The archive contains `tanstack/SKILL.md` and can be uploaded in Claude's skill settings.

## Edit

Edit `tanstack/SKILL.md`, run `./build.sh`, then re-upload `dist/tanstack.skill`.

The YAML frontmatter must contain `name` and `description`; `description` must be ≤ 1024 characters.

## License

MIT — see [LICENSE](./LICENSE).

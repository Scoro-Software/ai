# Scoro Skills

Agent skills that give AI coding assistants accurate, up-to-date guidance on working with Scoro APIs — without any other documentation.

## Available skills

| Skill | Description | Status |
|---|---|---|
| [api-best-practices](./api-best-practices/) | Scoro API v4 best practices — auth, conventions, data model, CRM sync, finance, resource planning, time tracking, v2→v4 migration, and starter scripts that generate a typed client or a markdown endpoint reference with openapi-generator | ✅ Available |

## Installation

### Claude Code

**As a plugin.** The whole repo is a Claude Code plugin. Register it as a marketplace once, then install:

```bash
claude plugin marketplace add Scoro-Software/ai
claude plugin install scoro@scoro-ai
```

Invoke the API skill with `/scoro:api-best-practices` in any session. The skill's `SKILL.md` loads automatically on invocation, and reference guides in `references/` are opened by the agent on demand.

The skill's `scripts/` folder holds starter scripts that generate a typed client (`generate-client.sh <generator>`) or a browsable endpoint reference (`generate-docs.sh`) from the public OpenAPI schema with openapi-generator. They need openapi-generator installed (Homebrew, npm or pip; Java 11+); see [`api-best-practices/scripts/README.md`](./api-best-practices/scripts/README.md). Installs that only reference `SKILL.md` by URL can still read the schema at `https://api.scoro.com/api/v4/reference/openapi` directly.

### Cursor

Add to your project's `.cursorrules`:

```
When working with the Scoro API, follow the guidance in:
https://raw.githubusercontent.com/Scoro-Software/ai/main/skills/api-best-practices/SKILL.md

Open the relevant file from skills/api-best-practices/references/ before implementing any integration.
```

Or copy `skills/api-best-practices/SKILL.md` content directly into `.cursorrules`.

### GitHub Copilot

Add to `.github/copilot-instructions.md`:

```markdown
## Scoro API
When writing code that calls the Scoro API, follow the guidance in `skills/api-best-practices/SKILL.md` and the relevant file in `skills/api-best-practices/references/`.
```

Then commit the whole `skills/api-best-practices/` folder, including `scripts/`, to your repo so Copilot can reference the files.

### Windsurf

Paste the contents of `skills/api-best-practices/SKILL.md` into your `.windsurfrules` file. For full coverage, include the relevant reference files too.

### Any agent (universal)

```
Read https://raw.githubusercontent.com/Scoro-Software/ai/main/skills/api-best-practices/SKILL.md and follow its guidance. Open the relevant reference file from references/ before implementing any Scoro API integration.
```

## Contributing

To add a new skill, create a directory under `skills/` with a `SKILL.md` entry point and a `references/` folder of domain guides. Open a pull request describing what the skill teaches and who it's for.

To improve an existing skill, edit the relevant reference file. Include the specific API behavior you verified (endpoint, field name, observed behavior) so reviewers can validate the change.

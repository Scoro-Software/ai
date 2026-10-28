# Scoro AI

AI tooling for building on Scoro — skills, agents, and integrations for AI coding assistants.

## What's here

| Directory | Description |
|---|---|
| [`skills/`](./skills/) | Agent skills that teach AI coding assistants how to use Scoro APIs correctly |

## Install in Claude Code

This repo is a Claude Code plugin that bundles every skill under `skills/`. Register it as a marketplace once, then install:

```bash
claude plugin marketplace add Scoro-Software/ai
claude plugin install scoro@scoro-ai
```

Claude then loads the API skill on its own when a task touches the Scoro API, or you can invoke it with `/scoro:api-best-practices`.

The API skill ships starter scripts that generate a typed client or an endpoint reference from the public OpenAPI schema with openapi-generator; they need openapi-generator installed (see [`skills/api-best-practices/scripts/README.md`](./skills/api-best-practices/scripts/README.md)).

For Cursor, Copilot, Windsurf, or any other agent, see [`skills/README.md`](./skills/README.md) — those platforms don't support Claude plugins, so the skills install there by file copy or raw-URL reference.

## Getting started

Browse the relevant directory for what you're building. Each sub-directory has its own README with installation instructions and usage guidance.

## Contributing

Open a pull request. Include what the contribution teaches or enables, and what you verified against a live Scoro site.

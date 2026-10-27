# Scoro AI

AI tooling for building on Scoro — skills, agents, and integrations for AI coding assistants.

## What's here

| Directory | Description |
|---|---|
| [`skills/`](./skills/) | Agent skills that teach AI coding assistants how to use Scoro APIs correctly |

## Install in Claude Code

This repo is a Claude Code plugin that bundles every skill under `skills/`.

```bash
claude plugin install scoro@scoro-ai
```

Then invoke the API skill with `/scoro:api-best-practices` in any session.

For Cursor, Copilot, Windsurf, or any other agent, see [`skills/README.md`](./skills/README.md) — those platforms don't support Claude plugins, so the skills install there by file copy or raw-URL reference.

## Getting started

Browse the relevant directory for what you're building. Each sub-directory has its own README with installation instructions and usage guidance.

## Contributing

Open a pull request. Include what the contribution teaches or enables, and what you verified against a live Scoro site.
